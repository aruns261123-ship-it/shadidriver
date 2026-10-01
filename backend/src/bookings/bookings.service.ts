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
import { TripType } from '../common/domain/trip-type';
import { AdminBookingDto, CustomerBookingDto, DriverAssignmentDto } from './booking-view.dto';

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
  /** ONE-WAY route distance (pickup → destination). */
  routeDistanceKm?: number;
  /** ONE_WAY | ROUND_TRIP — re-quote applies the server-side ×2 rule. */
  tripType?: TripType;
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
        // Same privacy contract as every other booking response: the customer
        // view only. A replay must never become a raw-row (idempotency key /
        // OTP hash) back door.
        return {
          booking: await this.getBookingById(existing.id, {
            userId: input.customerId,
            role: Role.Customer,
          }),
          idempotentReplay: true,
        };
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

    // Server-side re-quote — client totals are NEVER trusted. The trip type
    // participates in the price: ROUND_TRIP bills the one-way route twice.
    const tripType = input.tripType ?? TripType.ONE_WAY;
    const quote = await this.quotesService.createQuote({
      serviceCategoryId: input.serviceCategoryId,
      vehicleTypeId: input.vehicleTypeId,
      city: input.city,
      serviceStartTime: input.serviceStartTime,
      serviceEndTime: input.serviceEndTime,
      routeDistanceKm: input.routeDistanceKm,
      tripType,
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
          tripType,
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

    // The submission response is the CUSTOMER view (the same serializer as
    // GET /bookings/:id): no idempotency key, no trip-OTP hash, no internal FK
    // ids. The raw row must never reach the wire just because it is fresh.
    return {
      booking: await this.getBookingById(booking.id, {
        userId: input.customerId,
        role: Role.Customer,
      }),
      idempotentReplay: false,
    };
  }

  // ------------------------------------------- operations-owned allocation
  /**
   * OPERATIONS assigns a chauffeur to a booking (product model: the customer
   * never picks a driver and a driver never claims a customer booking).
   * Admin-only. Transactional: row-locked re-read, availability lock inserted
   * — two concurrent assignments of the same window cannot both succeed.
   *
   * The trip OTP is generated here because assignment is the moment the trip
   * becomes real; it is hashed at rest and delivered to the HOST's phone.
   * The driver never stores or sees the code in advance.
   */
  async assignChauffeur(bookingId: string, driverId: string, admin: { userId: string; role: Role }) {
    if (!['operationsAdmin', 'superAdmin'].includes(admin.role)) {
      throw new UnauthorizedException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only ShadiDriver operations may allocate chauffeurs.',
      );
    }
    const driver = await this.prisma.driverProfile.findUnique({
      where: { id: driverId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    if (driver.verificationStatus !== 'APPROVED') {
      throw new ConflictAppException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only verified chauffeurs can be assigned a duty.',
      );
    }

    const tripOtp = generateTripOtp();

    const result = await this.prisma.$transaction(async (tx) => {
      // SELECT ... FOR UPDATE via raw query to serialize concurrent decisions.
      // Column note: Prisma maps driverFk → "driver_id" in the bookings table.
      const locked = await tx.$queryRaw<{ status: string; id: string; driver_fk: string | null }[]>`
        SELECT "status", "id", "driver_id" AS "driver_fk" FROM "bookings" WHERE "id" = ${bookingId}::uuid FOR UPDATE`;
      if (!locked || locked.length === 0) {
        throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
      }
      const current = locked[0];
      const assignable = [
        BookingStatus.REQUESTED,
        BookingStatus.UNDER_REVIEW,
        BookingStatus.VEHICLE_OPTIONS_PREPARED,
        BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
        BookingStatus.CONFIRMED,
      ].includes(current.status as BookingStatus);
      if (!assignable) {
        throw new ConflictAppException(
          ErrorCode.BOOKING_NOT_IN_REQUESTED_STATE,
          `Booking in state ${current.status} cannot be allocated.`,
        );
      }
      if (current.driver_fk && current.driver_fk !== driverId) {
        throw new ConflictAppException(
          ErrorCode.BOOKING_NOT_IN_REQUESTED_STATE,
          'A chauffeur is already allocated. Unassign before re-allocating.',
        );
      }

      const previousStatus = current.status;
      const booking = await tx.booking.update({
        where: { id: bookingId },
        data: {
          driverFk: driver.id,
          // Allocation is an operational fact, not a customer-facing offer:
          // the booking only advances to DRIVER_ACCEPTED from REQUESTED.
          status:
            previousStatus === BookingStatus.REQUESTED
              ? BookingStatus.DRIVER_ACCEPTED
              : (previousStatus as BookingStatus),
          version: { increment: 1 },
          // Dynamic trip OTP — crypto-secure, hashed at rest. The plaintext
          // is delivered to the HOST's phone via SMS (after commit); the
          // chauffeur validates by entry, never by storage.
          startOtpHash: hashOtp(tripOtp),
        },
        // Ship the duty's car in the allocation response (model + fleet code).
        include: {
          vehicle: {
            select: {
              fleetCode: true,
              vehicleType: { select: { displayName: true } },
            },
          },
        },
      });

      await tx.bookingEvent.create({
        data: {
          bookingId,
          fromStatus: previousStatus,
          toStatus: booking.status,
          triggeredByUserId: admin.userId,
          triggerRole: 'operationsAdmin',
          eventReason: 'Operations allocated a chauffeur',
          eventMetadata: { driverId },
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
    // failure is logged and surfaced via the resend endpoint — the
    // allocation stands, and the OTP can be re-sent at any time.
    try {
      await this.sms.sendOtp(result.primaryContactPhone, tripOtp);
    } catch (err) {
      // Operational alert (no secret): OTP delivery failed post-allocation.
      console.error(
        `[trip-otp] SMS delivery failed for booking ${bookingId}:`,
        err instanceof Error ? err.message : String(err),
      );
    }

    return DriverAssignmentDto.from({
      ...result,
      customer: {
        id: result.customerFk,
        // The booking's primary contact IS the host for this duty.
        fullName: result.primaryContactName,
        phoneNumber: result.primaryContactPhone,
      },
    });
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

  /**
   * An ASSIGNED chauffeur reports a conflict (illness, vehicle issue…).
   * NOT a marketplace decline: the booking does not churn and the customer
   * sees no chauffeur-level change — the duty returns to the operations
   * queue for re-allocation. The chauffeur's link is released and any
   * calendar lock for this booking held by them is freed.
   */
  async reportAssignmentConflict(
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
    if (booking.driverFk !== driver.id) {
      // Not your duty — and not enumerable.
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }
    if (
      ![BookingStatus.DRIVER_ACCEPTED, BookingStatus.CONFIRMED].includes(
        booking.status as BookingStatus,
      )
    ) {
      throw new ConflictAppException(
        ErrorCode.INVALID_TRANSITION,
        'This duty can no longer be released — contact operations.',
      );
    }

    await this.prisma.$transaction([
      this.prisma.booking.update({
        where: { id: bookingId },
        data: {
          driverFk: null,
          status: BookingStatus.UNDER_REVIEW,
          version: { increment: 1 },
        },
      }),
      this.prisma.bookingEvent.create({
        data: {
          bookingId,
          fromStatus: booking.status,
          toStatus: BookingStatus.UNDER_REVIEW,
          triggeredByUserId: driverUserId,
          triggerRole: 'driver',
          eventReason: `Chauffeur reported a conflict: ${reason}`,
          eventMetadata: { notes: notes ?? null },
        },
      }),
      this.prisma.availability.updateMany({
        where: { bookingId, driverId: driver.id, status: 'BOOKED' },
        data: { status: 'AVAILABLE' },
      }),
    ]);
    return { released: true };
  }

  // --------------------------------------------------- state transitions
  async transition(
    bookingId: string,
    action: string,
    actor: { userId: string; role: Role },
    metadata?: Record<string, unknown>,
  ) {
    await this.prisma.$transaction(async (tx) => {
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
    // NEVER return the raw row: it carries the trip-OTP hash, the idempotency
    // key, and internal FK ids. A 4-digit OTP hash is brute-forceable offline
    // in milliseconds — the hash must not reach the chauffeur (or anyone else)
    // who is meant to ENTER the code rather than read it. Every actor gets the
    // role-scoped privacy view instead.
    return this.getBookingById(bookingId, actor);
  }

  // ------------------------------------------------------------ queries
  /**
   * Booking detail, serialized by VIEWER ROLE (privacy DTOs):
   *   customer → own booking, NEVER the assigned chauffeur's identity or
   *              phone (the customer sees "verified by ShadiDriver", not a
   *              person);
   *   driver   → only bookings they are operationally assigned to, with the
   *              operational minimum (host name/phone for the duty);
   *   admin    → full workspace view.
   * Unauthenticated or unrelated callers get the same 404 as a missing row.
   */
  async getBookingById(bookingId: string, viewer: { userId: string; role: Role }) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        customer: { select: { id: true, fullName: true, phoneNumber: true } },
        driver: { include: { user: { select: { fullName: true, phoneNumber: true } } } },
        vehicle: { select: { fleetCode: true, vehicleType: { select: { displayName: true } } } },
        serviceCategory: true,
        events: { orderBy: { createdAt: 'desc' }, take: 20 },
      },
    });
    if (!booking) {
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }

    const isAdmin = ['operationsAdmin', 'verificationAdmin', 'financeAdmin', 'superAdmin'].includes(
      viewer.role,
    );
    const isCustomer = viewer.userId === booking.customerFk;
    let isAssignedDriver = false;
    if (viewer.role === Role.Driver && booking.driverFk) {
      const ownProfile = await this.prisma.driverProfile.findUnique({
        where: { userId: viewer.userId },
        select: { id: true },
      });
      isAssignedDriver = ownProfile?.id === booking.driverFk;
    }
    if (!isAdmin && !isCustomer && !isAssignedDriver) {
      // Not your booking — and not enumerable.
      throw new NotFoundAppException(ErrorCode.BOOKING_NOT_FOUND, 'Booking not found.');
    }

    if (isAdmin) {
      return AdminBookingDto.from(booking);
    }
    if (isAssignedDriver) {
      return DriverAssignmentDto.from(booking);
    }
    return CustomerBookingDto.from(booking);
  }

  async listMyBookings(customerId: string, page: number, limit: number) {
    const [rows, total] = await Promise.all([
      this.prisma.booking.findMany({
        where: { customerFk: customerId },
        orderBy: { submittedAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          customer: { select: { id: true, fullName: true, phoneNumber: true } },
          vehicle: {
            select: { fleetCode: true, vehicleType: { select: { displayName: true } } },
          },
        },
      }),
      this.prisma.booking.count({ where: { customerFk: customerId } }),
    ]);
    return {
      // The customer's OWN bookings, serialized through the customer view:
      // no chauffeur identity, no driver FK, no idempotency key, no OTP hash.
      items: rows.map((row) =>
        CustomerBookingDto.from({
          ...row,
          // Signal THAT a chauffeur is allocated without shipping WHO they
          // are: the DTO only reads the presence of this relation.
          driver: row.driverFk ? { id: row.driverFk, user: null } : null,
        }),
      ),
      meta: { page, limit, total_records: total, has_more: page * limit < total },
    };
  }

  /**
   * Chauffeur's OWN duty list — assignments only. There are no "offers": the
   * customer's request is owned by ShadiDriver operations end-to-end, and a
   * chauffeur only ever sees work operations allocated to them.
   */
  async listDriverBookings(driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    const active = await this.prisma.booking.findMany({
      where: {
        driverFk: driver.id,
        status: { in: [BookingStatus.DRIVER_ACCEPTED, BookingStatus.CONFIRMED, BookingStatus.EN_ROUTE, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS] },
      },
      orderBy: { serviceStartTime: 'asc' },
      include: {
        customer: { select: { fullName: true } },
        vehicle: { select: { fleetCode: true, vehicleType: { select: { displayName: true } } } },
      },
    });
    const completed = await this.prisma.booking.findMany({
      where: { driverFk: driver.id, status: BookingStatus.COMPLETED },
      orderBy: { completedAt: 'desc' },
      take: 20,
      include: {
        customer: { select: { fullName: true } },
        vehicle: { select: { fleetCode: true, vehicleType: { select: { displayName: true } } } },
      },
    });
    /** Shared row → driver view (never a raw Prisma row: no OTP hash, no
     *  idempotency key, no internal event trail on the driver wire). */
    const toDuty = (b: (typeof active)[number]) =>
      DriverAssignmentDto.from({
        ...b,
        customer: { id: b.customerFk, fullName: b.customer.fullName, phoneNumber: b.primaryContactPhone },
      });
    return {
      // Wire-compat key: the app's "offers" tab is now the assigned-duty list
      // (there is no accept/reject — acknowledgment is handled separately).
      offers: [],
      assignments: active.map(toDuty),
      completed: completed.map(toDuty),
    };
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
