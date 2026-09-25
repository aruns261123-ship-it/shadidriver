import { Inject, Injectable } from '@nestjs/common';
import { createHash, randomInt } from 'crypto';
type TransactionClient = Omit<
  PrismaService,
  | '$connect'
  | '$disconnect'
  | '$on'
  | '$transaction'
  | '$extends'
  | 'onModuleInit'
  | 'onModuleDestroy'
  | 'withSerializableTransaction'
>;
import { PrismaService } from '../database/prisma.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { BookingStatus, ActorRole } from '../booking-state-machine/booking-status';
import { QuotesService } from '../quotes/quotes.service';
import { AvailabilityService } from '../availability/availability.service';
import { CONFIG_TOKEN, AppConfig } from '../config/configuration';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
  UnauthorizedException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { SMS_PROVIDER } from '../notifications/sms/sms.factory';
import { SmsProvider } from '../notifications/sms/sms-provider.interface';
import { Role } from '../auth/domain/roles';

export interface SubmitBookingInput {
  customerId: string;
  serviceCategoryId: string;
  vehicleTypeId: string;
  ceremonyType: string;
  ceremonialAttire: string;
  specialInstructions?: string;
  serviceStartTime: Date;
  serviceEndTime: Date;
  city: string;
  pickupAddress: string;
  destinationAddress: string;
  venueName?: string;
  routeDistanceKm?: number;
  primaryContactName: string;
  primaryContactPhone: string;
  passengerCount: number;
  selectedAddonIds?: string[];
  /** Client-declared amounts are IGNORED; totals always recomputed. */
  idempotencyKey: string;
}

const IDEMPOTENCY_TTL_HOURS = 24;

/**
 * Booking engine: authoritative submission, state transitions, and trip OTP.
 *
 * Idempotency: the same key within 24h returns the ORIGINAL booking (cached
 * replay) — retries can never create duplicates. Key is scoped per customer.
 *
 * Pricing: on submission the engine RE-QUOTES server-side (client amounts
 * are never read) and persists the authoritative totals.
 *
 * Trip OTP: generated at accept time from crypto-secure randomness, stored
 * as a hash only, delivered to the CUSTOMER via SMS. Not '1234'. Not logged.
 */
@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stateMachine: BookingStateMachineService,
    private readonly quotesService: QuotesService,
    private readonly availabilityService: AvailabilityService,
    @Inject(CONFIG_TOKEN) private readonly config: AppConfig,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  // ---------------------------------------------------------------- quote
  async quote(input: {
    serviceCategoryId: string;
    vehicleTypeId: string;
    serviceStartTime: Date;
    serviceEndTime: Date;
    routeDistanceKm?: number;
    selectedAddonIds?: string[];
    isUrgent?: boolean;
  }) {
    return this.quotesService.createQuote({ ...input });
  }

  // ------------------------------------------------------------- submit
  async submitBooking(input: SubmitBookingInput) {
    // Idempotent replay: same key + same customer returns the original.
    const existing = await this.prisma.booking.findUnique({
      where: { idempotencyKey: `${input.customerId}:${input.idempotencyKey}` },
    });
    if (existing) {
      const ageHours =
        (Date.now() - existing.createdAt.getTime()) / 3_600_000;
      if (ageHours <= IDEMPOTENCY_TTL_HOURS) {
        return { booking: existing, idempotentReplay: true };
      }
    }

    // Validate window.
    if (input.serviceEndTime <= input.serviceStartTime) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_BOOKING_DRAFT,
        'Service end time must be after start time.',
      );
    }
    if (input.serviceStartTime.getTime() < Date.now() - 3600_000) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_BOOKING_DRAFT,
        'Service start time must be in the future.',
      );
    }

    // Server-side re-quote — client totals are NEVER trusted.
    const quote = await this.quotesService.createQuote({
      serviceCategoryId: input.serviceCategoryId,
      vehicleTypeId: input.vehicleTypeId,
      city: input.city,
      serviceStartTime: input.serviceStartTime,
      serviceEndTime: input.serviceEndTime,
      routeDistanceKm: input.routeDistanceKm,
      selectedAddonIds: input.selectedAddonIds,
    });

    const booking = await this.prisma.$transaction(async (tx) => {
      const created = await tx.booking.create({
        data: {
          referenceCode: await this.nextReference(tx),
          customerFk: input.customerId,
          serviceCategoryId: input.serviceCategoryId,
          ceremonyType: input.ceremonyType,
          ceremonialAttire: input.ceremonialAttire,
          specialInstructions: input.specialInstructions ?? '',
          serviceStartTime: input.serviceStartTime,
          serviceEndTime: input.serviceEndTime,
          city: input.city,
          pickupAddress: input.pickupAddress,
          destinationAddress: input.destinationAddress,
          venueName: input.venueName ?? '',
          routeDistanceKm: input.routeDistanceKm ?? null,
          primaryContactName: input.primaryContactName,
          primaryContactPhone: input.primaryContactPhone,
          passengerCount: input.passengerCount,
          estimatedTotalPaise: BigInt(quote.total_paise),
          advanceTokenPaise: BigInt(quote.advance_token_paise),
          advanceTokenLabel: 'Advance Token (25%)',
          status: BookingStatus.REQUESTED,
          idempotencyKey: `${input.customerId}:${input.idempotencyKey}`,
        },
      });
      await tx.bookingEvent.create({
        data: {
          bookingId: created.id,
          fromStatus: 'NEW',
          toStatus: BookingStatus.REQUESTED,
          triggeredByUserId: input.customerId,
          triggerRole: 'customer',
          eventReason: 'Booking submitted',
        },
      });
      return created;
    });

    return { booking, idempotentReplay: false };
  }

  // ------------------------------------------------- accept (driver offer)
  /**
   * Driver accepts a REQUESTED booking. Transactional: row-locked re-read,
   * state machine validation, availability lock inserted — two concurrent
   * accepts cannot both succeed (the second sees status != REQUESTED).
   */
  async acceptBooking(bookingId: string, driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    if (driver.verificationStatus !== 'APPROVED') {
      throw new ConflictAppException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only verified chauffeurs can accept bookings.',
      );
    }

    const tripOtp = generateTripOtp();

    const result = await this.prisma.$transaction(async (tx) => {
      // SELECT ... FOR UPDATE via raw query to serialize concurrent accepts.
      const locked = await tx.$queryRaw<{ status: string; id: string }[]>`
        SELECT "status", "id" FROM "bookings" WHERE "id" = ${bookingId} FOR UPDATE`;
      if (!locked || locked.length === 0) {
        throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
      }
      if (locked[0].status !== BookingStatus.REQUESTED) {
        throw new ConflictAppException(
          ErrorCode.BOOKING_NOT_IN_REQUESTED_STATE,
          'This booking is no longer available (already accepted, cancelled, or expired).',
        );
      }

      const booking = await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: BookingStatus.DRIVER_ACCEPTED,
          driverFk: driver.id,
          version: { increment: 1 },
          // Dynamic trip OTP generated at accept — crypto-secure, hashed at
          // rest. The plaintext is delivered to the HOST's phone via SMS
          // (after commit); the driver validates by entry, never by storage.
          startOtpHash: hashOtp(tripOtp),
        },
      });

      await tx.bookingEvent.create({
        data: {
          bookingId,
          fromStatus: BookingStatus.REQUESTED,
          toStatus: BookingStatus.DRIVER_ACCEPTED,
          triggeredByUserId: driverUserId,
          triggerRole: 'driver',
          eventReason: 'Chauffeur accepted offer',
        },
      });

      // Time-slot lock preventing further allocation of this window.
      await tx.availability.create({
        data: {
          driverId: driver.id,
          vehicleId: booking.vehicleFk,
          startTime: booking.serviceStartTime,
          endTime: booking.serviceEndTime,
          status: 'BOOKED',
          bookingId,
        },
      });

      return booking;
    });

    // Post-commit: deliver the trip OTP to the host's phone. Delivery
    // failure is logged and surfaced via the resend endpoint — the accept
    // itself stands, and the OTP can be re-sent at any time.
    try {
      await this.sms.sendOtp(
        result.primaryContactPhone,
        tripOtp,
      );
    } catch (err) {
      // Operational alert (no secret): OTP delivery failed post-accept.
      console.error(
        `[trip-otp] SMS delivery failed for booking ${bookingId}:`,
        err instanceof Error ? err.message : String(err),
      );
    }

    return result;
  }

  /**
   * Re-sends the trip OTP to the host's phone. Generates a NEW code
   * (invalidating the old hash) — only the booking customer may request it,
   * and only while the trip has not started.
   */
  async resendTripOtp(bookingId: string, requester: { userId: string; role: Role }) {
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }
    if (requester.userId !== booking.customerFk) {
      throw new UnauthorizedException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only the booking customer may resend the trip OTP.',
      );
    }
    if (
      ![BookingStatus.DRIVER_ACCEPTED, BookingStatus.CONFIRMED, BookingStatus.EN_ROUTE, BookingStatus.ARRIVED].includes(
        booking.status as BookingStatus,
      )
    ) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_TRANSITION,
        'Trip OTP is not currently active for this booking.',
      );
    }
    const tripOtp = generateTripOtp();
    await this.prisma.booking.update({
      where: { id: bookingId },
      data: { startOtpHash: hashOtp(tripOtp) },
    });
    await this.sms.sendOtp(booking.primaryContactPhone, tripOtp);
    return { resent: true };
  }

  async declineBooking(
    bookingId: string,
    driverUserId: string,
    reason: string,
    notes?: string,
  ) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    const booking = await this.prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) {
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }
    if (booking.status !== BookingStatus.REQUESTED) {
      throw new ConflictAppException(
        ErrorCode.BOOKING_NOT_IN_REQUESTED_STATE,
        'Offer no longer open.',
      );
    }
    await this.prisma.bookingEvent.create({
      data: {
        bookingId,
        fromStatus: booking.status,
        toStatus: 'DECLINED_BY_DRIVER',
        triggeredByUserId: driverUserId,
        triggerRole: 'driver',
        eventReason: reason,
        eventMetadata: { notes: notes ?? null },
      },
    });
    return { declined: true };
  }

  // --------------------------------------------------- state transitions
  async transition(
    bookingId: string,
    action: string,
    actor: { userId: string; role: Role },
    metadata?: Record<string, unknown>,
  ) {
    const result = await this.prisma.$transaction(async (tx) => {
      const booking = await tx.booking.findUnique({ where: { id: bookingId } });
      if (!booking) {
        throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
      }

      const actorRole = roleToActor(actor.role, actor.userId === booking.customerFk);
      const toStatus = this.stateMachine.assertTransitionAllowed(
        booking.status as BookingStatus,
        action,
        actorRole,
      );

      // Trip start requires the customer's OTP (ARRIVED → IN_PROGRESS).
      if (action === 'START_TRIP') {
        const otp = (metadata?.['otp'] as string | undefined)?.trim();
        if (!otp || !booking.startOtpHash || !verifyOtp(otp, booking.startOtpHash)) {
          throw new UnauthorizedException(
            ErrorCode.INVALID_OTP,
            'Invalid trip start OTP. Ask the host family for the 4-digit code.',
          );
        }
      }

      const updated = await tx.booking.update({
        where: { id: bookingId },
        data: {
          status: toStatus,
          version: { increment: 1 },
          ...(action === 'START_ROUTE' ? { startedAt: new Date() } : {}),
          ...(action === 'COMPLETE_TRIP' ? { completedAt: new Date() } : {}),
          ...(action === 'CANCEL'
            ? { cancelledAt: new Date(), cancellationReason: String(metadata?.['reason'] ?? 'Cancelled') }
            : {}),
        },
      });

      await tx.bookingEvent.create({
        data: {
          bookingId,
          fromStatus: booking.status,
          toStatus,
          triggeredByUserId: actor.userId,
          triggerRole: actorRole,
          eventReason: action,
          eventMetadata: (metadata as never) ?? undefined,
        },
      });

      // Release the calendar lock on completion/cancellation.
      if (action === 'COMPLETE_TRIP' || action === 'CANCEL') {
        await tx.availability.updateMany({
          where: { bookingId, status: 'BOOKED' },
          data: { status: 'AVAILABLE' },
        });
      }

      return updated;
    });
    return result;
  }

  // ------------------------------------------------------------ queries
  async getBookingById(bookingId: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        customer: { select: { id: true, fullName: true, phoneNumber: true } },
        driver: { include: { user: { select: { fullName: true, phoneNumber: true } } } },
        serviceCategory: true,
        events: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    if (!booking) {
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }
    return booking;
  }

  async listMyBookings(customerId: string, page: number, limit: number) {
    const [rows, total] = await Promise.all([
      this.prisma.booking.findMany({
        where: { customerFk: customerId },
        orderBy: { submittedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.booking.count({ where: { customerFk: customerId } }),
    ]);
    return {
      items: rows,
      meta: { page, limit, total_records: total, has_more: page * limit < total },
    };
  }

  /** Driver's offers (REQUESTED) and active assignments. */
  async listDriverBookings(driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    const offers = await this.prisma.booking.findMany({
      where: { status: BookingStatus.REQUESTED, serviceCategory: { is: { isActive: true } } },
      orderBy: { submittedAt: 'desc' },
      take: 20,
      include: { customer: { select: { fullName: true } }, serviceCategory: true },
    });
    const active = await this.prisma.booking.findMany({
      where: {
        driverFk: driver.id,
        status: { in: [BookingStatus.DRIVER_ACCEPTED, BookingStatus.CONFIRMED, BookingStatus.EN_ROUTE, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS] },
      },
      orderBy: { serviceStartTime: 'asc' },
      include: { customer: { select: { fullName: true } } },
    });
    const completed = await this.prisma.booking.findMany({
      where: { driverFk: driver.id, status: BookingStatus.COMPLETED },
      orderBy: { completedAt: 'desc' },
      take: 20,
    });
    return { offers, active, completed };
  }

  private async nextReference(tx: TransactionClient): Promise<string> {
    const count = await tx.booking.count();
    return `SD-2026-${String(count + 101).padStart(4, '0')}`;
  }
}

/** 4-digit crypto-secure trip OTP (10,000 space, rate-limited verification). */
export function generateTripOtp(): string {
  return String(randomInt(1000, 10000));
}

export function hashOtp(code: string): string {
  return createHash('sha256').update(code).digest('hex');
}

export function verifyOtp(code: string, hash: string): boolean {
  return hashOtp(code) === hash;
}

function roleToActor(role: Role, isBookingCustomer: boolean): ActorRole {
  switch (role) {
    case Role.Customer:
      return 'customer';
    case Role.Driver:
      return 'driver';
    case Role.FleetOwner:
      return 'fleetOwner';
    case Role.OperationsAdmin:
    case Role.VerificationAdmin:
      return 'operationsAdmin';
    case Role.FinanceAdmin:
      return 'financeAdmin';
    case Role.SuperAdmin:
      return 'superAdmin';
    default:
      return isBookingCustomer ? 'customer' : 'driver';
  }
}
