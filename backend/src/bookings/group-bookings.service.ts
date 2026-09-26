import { Inject, Injectable } from '@nestjs/common';
import { AssignmentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import { ActorRole, BookingStatus, TERMINAL_STATUSES } from '../booking-state-machine/booking-status';
import { AvailabilityService, FleetRequestLine } from '../availability/availability.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
  UnauthorizedException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { isAdminRole, Role } from '../auth/domain/roles';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { SMS_PROVIDER } from '../notifications/sms/sms.factory';
import { SmsProvider } from '../notifications/sms/sms-provider.interface';
import { generateTripOtp, hashOtp, verifyOtp } from './bookings.service';
import {
  advanceFor,
  crossesMidnight,
  deriveLineQuote,
  serviceHours,
} from './group-booking-pricing';

export interface SubmitGroupBookingInput {
  customerId: string;
  serviceCategoryId: string;
  ceremonyType: string;
  city: string;
  pickupAddress: string;
  destinationAddress: string;
  serviceStartTime: Date;
  serviceEndTime: Date;
  primaryContactName: string;
  primaryContactPhone: string;
  passengerCount: number;
  /** Confirmed fleet composition — must match an availability check the customer saw. */
  fleet: FleetRequestLine[];
  idempotencyKey: string;
  /** Optional customer requirements (decoration, child seat, early arrival …). */
  requirements?: string[];
  /** PHONE | WHATSAPP | EMAIL | PHONE_WHATSAPP */
  communicationPreference?: string;
}

/**
 * Group bookings: ONE parent reservation, MANY vehicle assignments.
 * Creation is fully transactional — a failure leaves no half-persisted
 * group. Fleet composition is re-validated against live availability at
 * submit time; if availability dropped below the confirmed composition,
 * the request is rejected (never silently substituted).
 */
@Injectable()
export class GroupBookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availabilityService: AvailabilityService,
    private readonly stateMachine: BookingStateMachineService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  async checkAvailability(input: {
    fleet: FleetRequestLine[];
    serviceStartTime: Date;
    serviceEndTime: Date;
    city?: string;
  }) {
    return this.availabilityService.checkFleetAvailability(
      input.fleet,
      input.serviceStartTime,
      input.serviceEndTime,
      input.city,
    );
  }

  async submitGroupBooking(input: SubmitGroupBookingInput) {
    if (!input.fleet || input.fleet.length === 0) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Fleet composition is required.',
      );
    }

    // Idempotency (same scope as single bookings).
    const idemKey = `${input.customerId}:grp:${input.idempotencyKey}`;
    const existing = await this.prisma.groupBooking.findUnique({
      where: { idempotencyKey: idemKey },
      include: { assignments: true },
    });
    if (existing) return { groupBooking: existing, idempotentReplay: true };

    // Re-validate availability for the EXACT confirmed composition.
    const availability = await this.availabilityService.checkFleetAvailability(
      input.fleet,
      input.serviceStartTime,
      input.serviceEndTime,
      input.city,
    );
    if (!availability.fully_available) {
      throw new ConflictAppException(
        ErrorCode.FLEET_INSUFFICIENT_AVAILABILITY,
        'Fleet availability changed. No vehicles were substituted — please review the shortfall and confirm again.',
        {
          lines: availability.lines.map((l) => ({
            vehicle_type_id: l.vehicle_type_id,
            requested: l.requested,
            available: l.available,
            shortfall: l.shortfall,
          })),
        },
      );
    }

    // Load vehicle types + pick concrete available vehicles per type.
    const groupBooking = await this.prisma.$transaction(async (tx) => {
      const typeIds = input.fleet.map((f) => f.vehicleTypeId);
      const types = await tx.vehicleType.findMany({ where: { id: { in: typeIds } } });
      const typeMap = new Map(types.map((t) => [t.id, t]));

      const allocatedIds = new Set(
        (
          await tx.availability.findMany({
            where: {
              status: 'BOOKED',
              vehicleId: { not: null },
              startTime: { lt: input.serviceEndTime },
              endTime: { gt: input.serviceStartTime },
            },
            select: { vehicleId: true },
          })
        ).map((a) => a.vehicleId as string),
      );

      const hours = serviceHours(input.serviceStartTime, input.serviceEndTime);
      const overnight = crossesMidnight(input.serviceStartTime, input.serviceEndTime);
      let quotedTotalPaise = 0n;
      const unpricedVehicleIds: string[] = [];
      const quotedLines: Array<Record<string, unknown>> = [];
      // No chauffeur is bound at submit time. The customer requests vehicles;
      // ShadiDriver operations assigns chauffeurs internally afterwards, so a
      // reservation must never wait on (or be lost to) a driver offer loop.
      const assignmentsData: Array<{
        vehicleId: string;
        sequenceNumber: number;
        requestedModel: string;
        estimatedTotalPaise: bigint | null;
        advanceTokenPaise: bigint | null;
        pricingSnapshot: Prisma.InputJsonValue;
      }> = [];
      let sequence = 1;

      for (const line of input.fleet) {
        const type = typeMap.get(line.vehicleTypeId);
        if (!type) {
          throw new BadRequestAppException(
            ErrorCode.VALIDATION_FAILED,
            `Unknown vehicle type ${line.vehicleTypeId}`,
          );
        }
        // Eligibility is a property of the VEHICLE (verified, active,
        // available, not already allocated) — never of whether a chauffeur
        // happens to be attached to it. Partner/fleet-owner vehicles are
        // first-class members of the catalog.
        const candidates = await tx.vehicle.findMany({
          where: {
            vehicleTypeId: line.vehicleTypeId,
            verificationStatus: 'APPROVED',
            isActive: true,
            isAvailable: true,
            city: { contains: input.city, mode: 'insensitive' },
          },
          take: line.quantity * 3,
        });
        const eligible = candidates.filter((v) => !allocatedIds.has(v.id));
        if (eligible.length < line.quantity) {
          throw new ConflictAppException(
            ErrorCode.FLEET_INSUFFICIENT_AVAILABILITY,
            `Only ${eligible.length} of ${line.quantity} requested ${type.displayName} could be allocated. Nothing was substituted.`,
          );
        }
        const chosen = eligible.slice(0, line.quantity);
        for (const vehicle of chosen) {
          allocatedIds.add(vehicle.id);
          // Price comes from the vehicle's newest APPROVED tariff — NEVER from
          // a client, and never from the legacy base_price column (which
          // defaults to 0 and would advertise the fleet as free).
          const tariff = await tx.vehiclePricing.findFirst({
            where: { vehicleId: vehicle.id, status: 'APPROVED' },
            orderBy: { version: 'desc' },
          });
          const quote = deriveLineQuote(tariff, hours, overnight);
          if (quote.amountPaise == null) {
            unpricedVehicleIds.push(vehicle.id);
          } else {
            quotedTotalPaise += quote.amountPaise;
          }
          quotedLines.push({
            assignment_vehicle_id: vehicle.id,
            vehicle_type_id: line.vehicleTypeId,
            requested_model: type.displayName,
            basis: quote.basis,
            amount_paise: quote.amountPaise?.toString() ?? null,
            tariff_version: quote.tariffVersion ?? null,
          });
          assignmentsData.push({
            vehicleId: vehicle.id,
            sequenceNumber: sequence++,
            requestedModel: type.displayName,
            estimatedTotalPaise: quote.amountPaise,
            advanceTokenPaise:
              quote.amountPaise != null ? advanceFor(quote.amountPaise) : null,
            pricingSnapshot: {
              source: 'TARIFF_AUTO',
              quoted_at: new Date().toISOString(),
              service_hours: hours,
              crosses_midnight: overnight,
              basis: quote.basis,
              amount_paise: quote.amountPaise?.toString() ?? null,
              billable_hours: quote.billableHours ?? null,
              included_km: quote.includedKm ?? null,
              per_km_paise: quote.perKmPaise?.toString() ?? null,
              tariff_version: quote.tariffVersion ?? null,
              tariff_id: quote.tariffId ?? null,
            },
          });
        }
      }

      // A quote is only complete when EVERY reserved vehicle is priced. An
      // incomplete quote is stored as NULL with the reason, so the price shown
      // is "on request" rather than a fabricated zero.
      const quoteComplete = unpricedVehicleIds.length === 0;
      const totalPaise = quoteComplete ? quotedTotalPaise : null;
      const totalAdvance = quoteComplete
        ? assignmentsData.reduce((s, a) => s + (a.advanceTokenPaise ?? 0n), 0n)
        : null;

      const group = await tx.groupBooking.create({
        data: {
          referenceCode: `SD-GRP-2026-${String(Date.now()).slice(-6)}`,
          customerFk: input.customerId,
          serviceCategoryId: input.serviceCategoryId,
          ceremonyType: input.ceremonyType,
          city: input.city,
          pickupAddress: input.pickupAddress,
          destinationAddress: input.destinationAddress,
          serviceStartTime: input.serviceStartTime,
          serviceEndTime: input.serviceEndTime,
          requestedFleet: input.fleet as never,
          requestedFleetItems: input.fleet as never,
          passengerCount: input.passengerCount,
          requirements: (input.requirements ?? []) as never,
          communicationPreference: input.communicationPreference ?? 'PHONE',
          estimatedTotalPaise: totalPaise,
          advanceTokenPaise: totalAdvance,
          pricingSnapshot: {
            source: 'TARIFF_AUTO',
            quoted_at: new Date().toISOString(),
            complete: quoteComplete,
            service_hours: hours,
            crosses_midnight: overnight,
            total_paise: totalPaise?.toString() ?? null,
            advance_paise: totalAdvance?.toString() ?? null,
            unpriced_vehicle_ids: unpricedVehicleIds,
            lines: quotedLines,
          } as unknown as never,
          // A customer submission is a REQUEST: operations reviews it before
          // anything is promised to the customer.
          status: BookingStatus.REQUESTED,
          idempotencyKey: idemKey,
        },
      });

      await tx.vehicleAssignment.createMany({
        data: assignmentsData.map((a) => ({
          ...a,
          groupBookingId: group.id,
          assignmentStatus: 'PROPOSED' as const,
        })),
      });

      // Calendar locks for every reserved vehicle window. The chauffeur lock is
      // added when operations assigns one (see assignChauffeur).
      await tx.availability.createMany({
        data: assignmentsData.map((a) => ({
          vehicleId: a.vehicleId,
          startTime: input.serviceStartTime,
          endTime: input.serviceEndTime,
          status: 'BOOKED' as const,
        })),
      });

      await tx.groupBookingEvent.create({
        data: {
          groupBookingId: group.id,
          fromStatus: BookingStatus.DRAFT,
          toStatus: BookingStatus.REQUESTED,
          action: 'SUBMIT_REQUEST',
          triggeredByUserId: input.customerId,
          triggerRole: Role.Customer,
        },
      });

      return group;
    });

    return { groupBooking, idempotentReplay: false };
  }

  /**
   * Customer-facing read. Ownership is enforced HERE, not in the controller:
   * an `:id` alone must never be enough to read someone else's booking — that
   * would leak another customer's addresses, requirements and pricing. Admins
   * (who legitimately read any booking) pass through `viewer.role`.
   * A non-owner gets 404, the same response as a nonexistent id, so the
   * endpoint cannot be used to probe which booking ids exist.
   */
  async getGroupBooking(id: string, viewer: AuthenticatedUser) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id },
      include: {
        assignments: {
          // Chauffeur PII is deliberately NOT loaded here: the customer-facing
          // serializer must not be one careless spread away from leaking it.
          include: { vehicle: { include: { vehicleType: true } } },
          orderBy: { sequenceNumber: 'asc' },
        },
      },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.customerFk !== viewer.userId && !isAdminRole(viewer.role)) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    return serializeCustomerGroupBooking(group);
  }

  /** Every group booking the signed-in customer owns, newest first. */
  async listMyGroupBookings(customerId: string, page = 1, limit = 20) {
    const [items, total] = await this.prisma.$transaction([
      this.prisma.groupBooking.findMany({
        where: { customerFk: customerId },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          assignments: {
            include: { vehicle: { include: { vehicleType: true } } },
            orderBy: { sequenceNumber: 'asc' },
          },
        },
      }),
      this.prisma.groupBooking.count({ where: { customerFk: customerId } }),
    ]);
    return {
      items: items.map((g) => serializeCustomerGroupBooking(g)),
      page,
      limit,
      total,
    };
  }

  // ----------------------------------------------------- trip execution

  /** Assignment states that count as "the duty is in progress or done". */
  private static readonly SERVICE_STARTED: AssignmentStatus[] = [
    AssignmentStatus.IN_PROGRESS,
    AssignmentStatus.COMPLETED,
  ];

  /**
   * The chauffeur executes their assigned duty. `milestone` is one of
   * EN_ROUTE | ARRIVED | START_SERVICE | COMPLETE — a strictly forward ladder
   * per assignment, validated against the row's own state (row-locked).
   *
   * START_SERVICE requires the CUSTOMER's trip OTP — generated server-side at
   * customer confirmation and delivered to the customer's phone. The chauffeur
   * never stores or sees the code in advance; they collect it in person.
   *
   * The PARENT booking advances automatically when the fleet's collective
   * progress warrants it, and every milestone writes a group_booking_event.
   */
  async recordMilestone(
    assignmentId: string,
    milestone: 'EN_ROUTE' | 'ARRIVED' | 'START_SERVICE' | 'COMPLETE',
    chauffeurUserId: string,
    otp?: string,
  ) {
    const driver = await this.ownChauffeurProfile(chauffeurUserId);
    const targetStatus =
      milestone === 'EN_ROUTE'
        ? AssignmentStatus.EN_ROUTE
        : milestone === 'ARRIVED'
          ? AssignmentStatus.ARRIVED
          : milestone === 'START_SERVICE'
            ? AssignmentStatus.IN_PROGRESS
            : AssignmentStatus.COMPLETED;

    const previousGroupStatus = await this.prisma.$transaction(async (tx) => {
      const rows = await tx.$queryRaw<
        {
          id: string;
          driver_id: string | null;
          assignment_status: AssignmentStatus;
          group_booking_id: string | null;
        }[]
      >`SELECT "id", "driver_id", "assignment_status", "group_booking_id"
        FROM "vehicle_assignments" WHERE "id" = ${assignmentId}::uuid FOR UPDATE`;
      if (!rows?.length) {
        throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
      }
      const assignment = rows[0];
      if (assignment.driver_id !== driver.id) {
        // Not yours — and not enumerable: same 404 as a missing row.
        throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
      }

      const legalPredecessors: Partial<Record<AssignmentStatus, AssignmentStatus[]>> = {
        [AssignmentStatus.EN_ROUTE]: [AssignmentStatus.CHAUFFEUR_ASSIGNED, AssignmentStatus.CHAUFFEUR_ACCEPTED],
        [AssignmentStatus.ARRIVED]: [AssignmentStatus.EN_ROUTE],
        [AssignmentStatus.IN_PROGRESS]: [AssignmentStatus.ARRIVED],
        [AssignmentStatus.COMPLETED]: [AssignmentStatus.IN_PROGRESS],
      };
      const from = assignment.assignment_status;
      if (!legalPredecessors[targetStatus]?.includes(from)) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Cannot record ${milestone} on an assignment in state ${from}.`,
        );
      }

      const groupId = assignment.group_booking_id;
      const group = groupId
        ? await tx.groupBooking.findUnique({ where: { id: groupId } })
        : null;
      if (!group) {
        throw new NotFoundAppException(
          ErrorCode.GROUP_BOOKING_NOT_FOUND,
          'Assignment is not part of a group booking.',
        );
      }
      // Only an executed booking can be progressed. An unconfirmed or cancelled
      // booking must never be driven forward by a chauffeur milestone.
      if (group.status !== BookingStatus.CONFIRMED && group.status !== BookingStatus.IN_PROGRESS) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `The booking is ${group.status}; service can only be executed on a CONFIRMED booking.`,
        );
      }

      // The customer's handover: starting service requires the OTP the
      // customer received when they confirmed the booking. It is passed per
      // request (NEVER stashed on the service — a singleton field would race
      // across concurrent chauffeurs).
      if (milestone === 'START_SERVICE') {
        const code = otp?.trim();
        if (!code || !group.startOtpHash || !verifyOtp(code, group.startOtpHash)) {
          throw new UnauthorizedException(
            ErrorCode.INVALID_OTP,
            'Invalid trip start OTP. Ask the customer for the code shown on their booking.',
          );
        }
      }

      await tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          assignmentStatus: targetStatus,
          ...(milestone === 'ARRIVED' ? { acceptedAt: new Date() } : {}),
        },
      });

      await tx.groupBookingEvent.create({
        data: {
          groupBookingId: group.id,
          fromStatus: group.status,
          toStatus: group.status,
          action: `CHAUFFEUR_${milestone}`,
          triggeredByUserId: chauffeurUserId,
          triggerRole: Role.Driver,
        },
      });

      // Parent advancement: the whole fleet is on the road / in service / done.
      const all = await tx.vehicleAssignment.findMany({
        where: { groupBookingId: group.id },
        select: { vehicleId: true, assignmentStatus: true },
      });
      const everyCompleted =
        all.length > 0 && all.every((a) => a.assignmentStatus === AssignmentStatus.COMPLETED);
      const anyStarted = all.some((a) =>
        GroupBookingsService.SERVICE_STARTED.includes(a.assignmentStatus),
      );

      // group.status is guaranteed CONFIRMED or IN_PROGRESS here (enforced
      // above), so completion is always a forward move — but the money must be
      // settled first: the balance outstanding means the trip cannot complete.
      if (everyCompleted && group.balancePaidAt == null) {
        throw new ConflictAppException(
          ErrorCode.PAYMENT_REQUIRED,
          'The balance settlement is outstanding — pay it before the trip can be completed.',
        );
      }
      if (everyCompleted) {
        await tx.groupBooking.update({
          where: { id: group.id },
          data: { status: BookingStatus.COMPLETED, version: { increment: 1 } },
        });
        await tx.groupBookingEvent.create({
          data: {
            groupBookingId: group.id,
            fromStatus: group.status,
            toStatus: BookingStatus.COMPLETED,
            action: 'COMPLETE_TRIP',
            triggeredByUserId: chauffeurUserId,
            triggerRole: Role.Driver,
          },
        });
        // Service delivered: the vehicles go back into the pool.
        await tx.availability.deleteMany({
          where: {
            vehicleId: { in: all.map((a) => a.vehicleId) },
            bookingId: null,
            status: 'BOOKED',
          },
        });
      } else if (anyStarted && group.status === BookingStatus.CONFIRMED) {
        await tx.groupBooking.update({
          where: { id: group.id },
          data: { status: BookingStatus.IN_PROGRESS, version: { increment: 1 } },
        });
        await tx.groupBookingEvent.create({
          data: {
            groupBookingId: group.id,
            fromStatus: BookingStatus.CONFIRMED,
            toStatus: BookingStatus.IN_PROGRESS,
            action: 'START_TRIP',
            triggeredByUserId: chauffeurUserId,
            triggerRole: Role.Driver,
          },
        });
      }

      return group.status;
    });

    return {
      assignment_id: assignmentId,
      assignment_status: targetStatus,
      booking_status: previousGroupStatus,
    };
  }

  /**
   * Re-sends the trip start OTP to the customer's phone. Only the booking's
   * owner may request it, only while the trip has not started, and each resend
   * generates a NEW code that invalidates the previous hash.
   */
  async resendTripOtp(id: string, requester: AuthenticatedUser) {
    const group = await this.prisma.groupBooking.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.customerFk !== requester.userId) {
      throw new UnauthorizedException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only the booking customer may resend the trip OTP.',
      );
    }
    if (group.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestAppException(
        ErrorCode.INVALID_TRANSITION,
        'Trip OTP is only active on a CONFIRMED booking.',
      );
    }
    const booking = await this.prisma.groupBooking.findUnique({
      where: { id },
      include: { customer: { select: { phoneNumber: true } } },
    });
    if (!booking?.customer) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    const tripOtp = generateTripOtp();
    await this.prisma.groupBooking.update({
      where: { id },
      data: { startOtpHash: hashOtp(tripOtp) },
    });
    await this.sms.sendOtp(booking.customer.phoneNumber, tripOtp);
    return { resent: true };
  }

  /**
   * CUSTOMER transitions on their own request. The customer can confirm the
   * options operations prepared, send them back for revision, or cancel — and
   * nothing else. The legal set is enforced by the shared state machine with
   * actor 'customer'; a customer can never drive the booking into a state
   * operations owns (CONFIRMED is only reachable from the confirmation-pending
   * state, which operations is the one to enter).
   */
  async customerTransition(
    id: string,
    action: string,
    viewer: AuthenticatedUser,
    reason?: string,
  ) {
    const group = await this.prisma.groupBooking.findUnique({ where: { id } });
    if (!group || group.customerFk !== viewer.userId) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    const target = this.stateMachine.assertTransitionAllowed(
      group.status as BookingStatus,
      action,
      'customer' as ActorRole,
    );
    if (action === 'REVISE_OPTIONS' && !reason?.trim()) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Tell operations what needs to change.',
      );
    }
    // A booking may only become CONFIRMED when the fleet really is ready. This
    // guard lives on the SHARED path: whether the customer taps confirm or
    // operations does, the same rule applies.
    if (action === 'CONFIRM_BOOKING') {
      await this.assertConfirmable(id);
    }
    return this.applyTransition({
      group,
      target,
      action,
      actorUserId: viewer.userId,
      actorRole: Role.Customer,
      reason,
    });
  }

  /**
   * A booking may only be PROMISED once every reserved vehicle is confirmed,
   * carries a chauffeur, and the price is real. Living on the shared service
   * (rather than only in the operations desk) means the customer's own confirm
   * tap cannot become a loophole that confirms a fleet nobody can field.
   */
  async assertConfirmable(id: string) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id },
      include: { assignments: { select: { id: true, driverId: true, assignmentStatus: true } } },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.assignments.length === 0) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'No vehicles are allocated yet — nothing can be confirmed with the customer.',
      );
    }
    const unconfirmed = group.assignments.filter(
      (a) => a.assignmentStatus === AssignmentStatus.PROPOSED,
    );
    if (unconfirmed.length > 0) {
      throw new ConflictAppException(
        ErrorCode.INVALID_TRANSITION,
        `${unconfirmed.length} reserved vehicle(s) still need an operations vehicle confirmation.`,
        { assignment_ids: unconfirmed.map((a) => a.id) },
      );
    }
    const withoutChauffeur = group.assignments.filter((a) => a.driverId == null);
    if (withoutChauffeur.length > 0) {
      throw new ConflictAppException(
        ErrorCode.INVALID_TRANSITION,
        `${withoutChauffeur.length} vehicle(s) have no chauffeur assigned yet.`,
        { assignment_ids: withoutChauffeur.map((a) => a.id) },
      );
    }
    if (group.estimatedTotalPaise == null) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This booking has no complete price yet — re-quote before confirming with the customer.',
      );
    }
  }

  /**
   * Applies a state-machine-approved transition: status + version + history in
   * ONE transaction, releasing calendar locks when the booking leaves the live
   * pipeline. Shared by the customer and operations paths so both write
   * identical history rows.
   */
  async applyTransition(input: {
    group: { id: string; status: string; version: number; estimatedTotalPaise?: bigint | null };
    target: BookingStatus;
    action: string;
    actorUserId: string;
    actorRole: Role;
    reason?: string;
  }) {
    const { group, target, action, actorUserId, actorRole, reason } = input;

    // The trip start OTP is minted at the moment the customer CONFIRMS — that
    // is when the fleet becomes real and the handover code becomes meaningful.
    // Hashed at rest; the plaintext is delivered to the customer's phone after
    // the transaction commits. Delivery failure is logged, not fatal: the
    // customer can request a fresh code (which invalidates this one).
    let tripOtp: string | null = null;
    if (action === 'CONFIRM_BOOKING') {
      tripOtp = generateTripOtp();
    }

    const result = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.groupBooking.update({
        where: { id: group.id },
        data: {
          status: target,
          version: { increment: 1 },
          ...(tripOtp ? { startOtpHash: hashOtp(tripOtp) } : {}),
        },
      });
      await tx.groupBookingEvent.create({
        data: {
          groupBookingId: group.id,
          fromStatus: group.status,
          toStatus: target,
          action,
          triggeredByUserId: actorUserId,
          triggerRole: actorRole,
          eventReason: reason ?? null,
        },
      });
      if (TERMINAL_STATUSES.includes(target)) {
        // The vehicles go back into the pool the moment the booking dies.
        await tx.availability.deleteMany({
          where: {
            vehicleId: {
              in: (
                await tx.vehicleAssignment.findMany({
                  where: { groupBookingId: group.id },
                  select: { vehicleId: true },
                })
              ).map((a) => a.vehicleId),
            },
            bookingId: null,
            status: 'BOOKED',
          },
        });
        const driverIds = (
          await tx.vehicleAssignment.findMany({
            where: { groupBookingId: group.id, driverId: { not: null } },
            select: { driverId: true },
          })
        ).map((a) => a.driverId as string);
        if (driverIds.length) {
          await tx.availability.deleteMany({
            where: { driverId: { in: driverIds }, bookingId: null, status: 'BOOKED' },
          });
        }
      }
      return {
        id: updated.id,
        reference_code: updated.referenceCode,
        status: updated.status,
        version: updated.version,
      };
    });

    // Post-commit: deliver the OTP to the customer. Never logged, never
    // returned in the response body.
    if (tripOtp) {
      try {
        const booking = await this.prisma.groupBooking.findUnique({
          where: { id: group.id },
          select: { customer: { select: { phoneNumber: true } } },
        });
        if (booking) {
          await this.sms.sendOtp(booking.customer.phoneNumber, tripOtp);
        }
      } catch (err) {
        // Operational alert only — no secret, no fake success.
        console.error(
          `[trip-otp] SMS delivery failed for group booking ${group.id}:`,
          err instanceof Error ? err.message : String(err),
        );
      }
    }
    return result;
  }

  /**
   * Operations: confirm the reserved vehicle for one assignment.
   * PROPOSED → VEHICLE_CONFIRMED. This is the step that used to be delegated
   * to the driver as an offer/accept loop; it is now an internal action.
   */
  async confirmVehicleAllocation(assignmentId: string, actorUserId: string) {
    return this.prisma.$transaction(async (tx) => {
      const assignment = await tx.vehicleAssignment.findUnique({
        where: { id: assignmentId },
        include: { vehicle: { include: { vehicleType: true } } },
      });
      if (!assignment) {
        throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
      }
      if (
        assignment.assignmentStatus !== AssignmentStatus.PROPOSED &&
        assignment.assignmentStatus !== AssignmentStatus.CHAUFFEUR_DECLINED
      ) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Cannot confirm an assignment in state ${assignment.assignmentStatus}.`,
        );
      }
      return tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          assignmentStatus: AssignmentStatus.VEHICLE_CONFIRMED,
          assignedByUserId: actorUserId,
          assignedAt: new Date(),
        },
      });
    });
  }

  /**
   * Operations: assign the chauffeur for a confirmed vehicle. VEHICLE_CONFIRMED
   * → CHAUFFEUR_ASSIGNED, and the chauffeur's calendar is locked for the same
   * window so the same person cannot be booked twice. The chauffeur is NEVER
   * notified as a marketplace offer and never contacts the customer to
   * negotiate — operations owns customer communication.
   */
  async assignChauffeur(assignmentId: string, driverId: string, actorUserId: string) {
    const chauffeur = await this.prisma.driverProfile.findUnique({ where: { id: driverId } });
    if (!chauffeur) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Chauffeur not found.');
    }
    if (chauffeur.verificationStatus !== 'APPROVED') {
      throw new ConflictAppException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only verified chauffeurs can be assigned to a booking.',
      );
    }
    return this.prisma.$transaction(async (tx) => {
      // The id is an explicit ::uuid cast because Prisma binds the parameter
      // as text, and Postgres has no uuid = text operator (error 42883).
      const locked = await tx.$queryRaw<
        { id: string; assignment_status: string; group_booking_id: string | null }[]
      >`SELECT "id", "assignment_status", "group_booking_id" FROM "vehicle_assignments"
        WHERE "id" = ${assignmentId}::uuid FOR UPDATE`;
      if (!locked?.length) {
        throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
      }
      if (locked[0].assignment_status === AssignmentStatus.VEHICLE_CONFIRMED ||
          locked[0].assignment_status === AssignmentStatus.CHAUFFEUR_DECLINED) {
        // legal source states
      } else {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Assign a chauffeur only to a confirmed vehicle (current: ${locked[0].assignment_status}).`,
        );
      }

      const groupId = locked[0].group_booking_id;
      const group = groupId
        ? await tx.groupBooking.findUnique({ where: { id: groupId } })
        : null;

      // Refuse overlapping chauffeur commitments inside the same window.
      if (group) {
        const clash = await tx.availability.findFirst({
          where: {
            driverId,
            status: 'BOOKED',
            startTime: { lt: group.serviceEndTime },
            endTime: { gt: group.serviceStartTime },
          },
        });
        if (clash) {
          throw new ConflictAppException(
            ErrorCode.SLOT_DOUBLE_BOOKED,
            'This chauffeur is already committed for an overlapping window.',
          );
        }
        await tx.availability.create({
          data: {
            driverId,
            startTime: group.serviceStartTime,
            endTime: group.serviceEndTime,
            status: 'BOOKED',
          },
        });
      }

      const assignment = await tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          driverId,
          assignmentStatus: AssignmentStatus.CHAUFFEUR_ASSIGNED,
          assignedByUserId: actorUserId,
          assignedAt: new Date(),
        },
      });

      // Parent advances out of REQUESTED once operations has committed a
      // chauffeur for every vehicle in the fleet.
      if (groupId) {
        const all = await tx.vehicleAssignment.findMany({
          where: { groupBookingId: groupId },
          select: { assignmentStatus: true },
        });
        const everyAssigned = all.every(
          (a) =>
            a.assignmentStatus === AssignmentStatus.CHAUFFEUR_ASSIGNED ||
            a.assignmentStatus === AssignmentStatus.CHAUFFEUR_ACCEPTED ||
            a.assignmentStatus === AssignmentStatus.VEHICLE_CONFIRMED,
        );
        // Advance ONLY from a pre-options state. Staffing a car is an internal
        // step and must never move a booking BACKWARDS: once operations has
        // asked the customer to confirm, adding or swapping a chauffeur cannot
        // silently un-ask them (that also used to wipe the customer's pending
        // confirmation out from under them).
        const isPreOptions =
          group?.status === BookingStatus.REQUESTED ||
          group?.status === BookingStatus.UNDER_REVIEW;
        if (everyAssigned && isPreOptions) {
          await tx.groupBooking.update({
            where: { id: groupId },
            data: {
              status: BookingStatus.VEHICLE_OPTIONS_PREPARED,
              version: { increment: 1 },
            },
          });
        }
      }

      return assignment;
    });
  }

  /** Driver-scoped assignment list — a chauffeur sees ONLY their own. */
  async listDriverAssignments(driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    const assignments = await this.prisma.vehicleAssignment.findMany({
      where: { driverId: driver.id },
      include: {
        groupBooking: {
          include: { customer: { select: { fullName: true, phoneNumber: true } } },
        },
        vehicle: { include: { vehicleType: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return assignments.map((a) => ({
      id: a.id,
      assignment_status: a.assignmentStatus,
      sequence_number: a.sequenceNumber,
      requested_model: a.requestedModel,
      group_reference: a.groupBooking?.referenceCode,
      ceremony_type: a.groupBooking?.ceremonyType,
      pickup_address: a.groupBooking?.pickupAddress,
      destination_address: a.groupBooking?.destinationAddress,
      service_start_time: a.groupBooking?.serviceStartTime,
      service_end_time: a.groupBooking?.serviceEndTime,
      host_name: a.groupBooking?.customer.fullName,
      host_phone: a.groupBooking?.customer.phoneNumber,
      vehicle: {
        display_name: a.vehicle.vehicleType.displayName,
        registration_number: a.vehicle.registrationNumber,
      },
    }));
  }

  /**
   * Chauffeur acknowledgement of a duty ALREADY assigned by operations. This
   * is not an offer and not a marketplace acceptance: the customer's booking
   * status never depends on it, and the customer is never told a chauffeur
   * is "accepting" their trip.
   */
  async acknowledgeAssignment(assignmentId: string, driverUserId: string) {
    const driver = await this.ownChauffeurProfile(driverUserId);
    return this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, assignmentId);
      if (locked.driver_id !== driver.id) {
        throw new ConflictAppException(
          ErrorCode.ROLE_FORBIDDEN,
          'This assignment belongs to another chauffeur.',
        );
      }
      if (locked.assignment_status !== AssignmentStatus.CHAUFFEUR_ASSIGNED) {
        throw new ConflictAppException(
          ErrorCode.INVALID_TRANSITION,
          `Cannot acknowledge an assignment in state ${locked.assignment_status}.`,
        );
      }
      return tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          assignmentStatus: AssignmentStatus.CHAUFFEUR_ACCEPTED,
          acceptedAt: new Date(),
        },
      });
    });
  }

  /**
   * Chauffeur reports a conflict. The vehicle stays reserved for the customer
   * (never silently dropped, never substituted) and returns to the operations
   * queue for re-assignment. The customer sees no churn.
   */
  async declineAssignment(assignmentId: string, driverUserId: string, reason: string) {
    const driver = await this.ownChauffeurProfile(driverUserId);
    return this.prisma.$transaction(async (tx) => {
      const locked = await this.lockAssignment(tx, assignmentId);
      if (locked.driver_id !== driver.id) {
        throw new ConflictAppException(
          ErrorCode.ROLE_FORBIDDEN,
          'This assignment belongs to another chauffeur.',
        );
      }
      // Release the chauffeur's calendar lock — the vehicle lock stays.
      await tx.availability.deleteMany({
        where: { driverId: driver.id, bookingId: null, status: 'BOOKED' },
      });
      return tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          assignmentStatus: AssignmentStatus.CHAUFFEUR_DECLINED,
          declinedAt: new Date(),
          declineReason: reason,
          driverId: null,
        },
      });
    });
  }

  private async ownChauffeurProfile(driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    return driver;
  }

  private async lockAssignment(
    tx: Prisma.TransactionClient,
    assignmentId: string,
  ): Promise<{
    id: string;
    assignment_status: AssignmentStatus;
    driver_id: string | null;
    group_booking_id: string | null;
  }> {
    const rows = await tx.$queryRaw<
      {
        id: string;
        assignment_status: AssignmentStatus;
        driver_id: string | null;
        group_booking_id: string | null;
      }[]
    >`SELECT "id", "assignment_status", "driver_id", "group_booking_id"
      FROM "vehicle_assignments" WHERE "id" = ${assignmentId}::uuid FOR UPDATE`;
    if (!rows?.length) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
    }
    return rows[0];
  }
}

interface CustomerGroupBookingSource {
  id: string;
  referenceCode: string;
  ceremonyType: string;
  city: string;
  pickupAddress: string;
  destinationAddress: string;
  serviceStartTime: Date;
  serviceEndTime: Date;
  passengerCount: number;
  status: string;
  version?: number;
  estimatedTotalPaise: bigint | null;
  advanceTokenPaise: bigint | null;
  requirements?: unknown;
  communicationPreference?: string;
  requestedFleetItems?: unknown;
  assignments: Array<{
    id: string;
    sequenceNumber: number;
    assignmentStatus: string;
    requestedModel: string | null;
    estimatedTotalPaise: bigint | null;
    advanceTokenPaise: bigint | null;
    vehicle: { id: string; fleetCode: string; vehicleType: { displayName: string } };
  }>;
}

/**
 * Keys that must never appear in a customer-facing booking payload. Listed
 * explicitly (rather than merely omitted) so intent is testable.
 */
export const CUSTOMER_FORBIDDEN_ASSIGNMENT_KEYS = [
  'driver',
  'driver_id',
  'chauffeur',
  'chauffeur_id',
  'chauffeur_name',
  'chauffeur_phone',
  'full_name',
  'phone',
  'registration_number',
  'fleet_owner',
  'partner',
  'decline_reason',
  'assigned_by_user_id',
  'internal_notes',
  'pricing_snapshot',
  'billable_hours',
  'tariff_id',
  'tariff_version',
] as const;

/**
 * CUSTOMER-FACING serialisation. Deliberately exhaustive and additive-only:
 * partner identity, registration numbers and chauffeur identity are internal
 * operational data and must never reach a customer response. Chauffeur state is
 * collapsed to a neutral boolean.
 */
export function serializeCustomerGroupBooking(group: CustomerGroupBookingSource) {
  return {
    id: group.id,
    reference_code: group.referenceCode,
    ceremony_type: group.ceremonyType,
    city: group.city,
    pickup_address: group.pickupAddress,
    destination_address: group.destinationAddress,
    service_start_time: group.serviceStartTime,
    service_end_time: group.serviceEndTime,
    passenger_count: group.passengerCount,
    status: group.status,
    version: group.version,
    // null means "operations has not quoted yet" — a REAL state, rendered as
    // "on request". Never coerced to 0 (which would read as a free booking).
    estimated_total_paise: group.estimatedTotalPaise?.toString() ?? null,
    advance_token_paise: group.advanceTokenPaise?.toString() ?? null,
    quote_pending: group.estimatedTotalPaise == null,
    requirements: group.requirements ?? [],
    communication_preference: group.communicationPreference ?? 'PHONE',
    requested_fleet: group.requestedFleetItems ?? [],
    assignments: group.assignments.map((a) => ({
      id: a.id,
      sequence_number: a.sequenceNumber,
      requested_model: a.requestedModel,
      vehicle: {
        id: a.vehicle.id,
        fleet_code: a.vehicle.fleetCode,
        display_name: a.vehicle.vehicleType.displayName,
      },
      // Neutral operational flag — never the chauffeur's identity.
      chauffeur_assigned:
        a.assignmentStatus === AssignmentStatus.CHAUFFEUR_ASSIGNED ||
        a.assignmentStatus === AssignmentStatus.CHAUFFEUR_ACCEPTED ||
        a.assignmentStatus === AssignmentStatus.EN_ROUTE ||
        a.assignmentStatus === AssignmentStatus.ARRIVED ||
        a.assignmentStatus === AssignmentStatus.IN_PROGRESS,
      service_state: customerVisibleServiceState(a.assignmentStatus),
      estimated_total_paise: a.estimatedTotalPaise?.toString() ?? null,
      advance_token_paise: a.advanceTokenPaise?.toString() ?? null,
    })),
  };
}

/**
 * Maps internal assignment progress onto the only four things a customer needs
 * to know about a vehicle. Chauffeur identity, decline/re-assignment churn and
 * partner sourcing are all invisible here.
 */
function customerVisibleServiceState(status: string): string {
  switch (status) {
    case AssignmentStatus.PROPOSED:
    case AssignmentStatus.VEHICLE_CONFIRMED:
    case AssignmentStatus.CHAUFFEUR_ASSIGNED:
    case AssignmentStatus.CHAUFFEUR_ACCEPTED:
    case AssignmentStatus.CHAUFFEUR_DECLINED:
      return 'BEING_PREPARED';
    case AssignmentStatus.EN_ROUTE:
      return 'ON_THE_WAY';
    case AssignmentStatus.ARRIVED:
      return 'ARRIVED';
    case AssignmentStatus.IN_PROGRESS:
      return 'IN_SERVICE';
    case AssignmentStatus.COMPLETED:
      return 'COMPLETED';
    case AssignmentStatus.CANCELLED:
      return 'CANCELLED';
    default:
      return 'BEING_PREPARED';
  }
}
