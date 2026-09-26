import { Injectable } from '@nestjs/common';
import { AssignmentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { ActorRole, BookingStatus } from '../booking-state-machine/booking-status';
import { BookingStateMachineService } from '../booking-state-machine/booking-state-machine.service';
import {
  advanceFor,
  crossesMidnight,
  deriveLineQuote,
  serviceHours,
} from '../bookings/group-booking-pricing';
import { GroupBookingsService } from '../bookings/group-bookings.service';
import { LogCustomerContactDto, OperationsTransitionDto, RequoteDto } from './dto/operations.dto';

/**
 * The operations booking workspace.
 *
 * This is the surface where a submitted customer REQUEST becomes a real,
 * executed booking: review → prepare vehicle options → assign chauffeurs
 * internally → contact the customer → get their confirmation → confirmed.
 *
 * Every mutation is audit-logged, and every read here is admin-gated (the
 * controller enforces that). Unlike the customer DTOs, this service
 * deliberately exposes partner + chauffeur identity and documents — that is
 * exactly the information the operations desk needs and the customer must
 * never receive.
 */
@Injectable()
export class OperationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stateMachine: BookingStateMachineService,
    private readonly groupBookings: GroupBookingsService,
  ) {}

  /** Statuses that still need a human. Terminal bookings leave the queue. */
  private static readonly OPEN_STATUSES: BookingStatus[] = [
    BookingStatus.DRAFT,
    BookingStatus.REQUESTED,
    BookingStatus.UNDER_REVIEW,
    BookingStatus.VEHICLE_OPTIONS_PREPARED,
    BookingStatus.CUSTOMER_CONFIRMATION_PENDING,
  ];

  // ------------------------------------------------------------------ queue

  /**
   * Operational queue — oldest request first, because an un-answered request is
   * a customer waiting. Not a statistics page: each row carries everything the
   * desk needs to decide whether to open it (customer, window, fleet readiness,
   * whether a chauffeur is still missing, whether we are waiting on them).
   */
  async bookingRequestQueue(filters: {
    status?: string;
    statuses?: string[];
    awaitingConfirmation?: boolean;
    city?: string;
  }) {
    const statusFilter = filters.status
      ? ([filters.status] as BookingStatus[])
      : filters.statuses?.length
        ? (filters.statuses as BookingStatus[])
        : OperationsService.OPEN_STATUSES;

    const where: Prisma.GroupBookingWhereInput = {
      status: { in: statusFilter },
      ...(filters.awaitingConfirmation
        ? { status: BookingStatus.CUSTOMER_CONFIRMATION_PENDING }
        : {}),
      ...(filters.city ? { city: { contains: filters.city, mode: 'insensitive' } } : {}),
    };

    const rows = await this.prisma.groupBooking.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      take: 100,
      include: {
        customer: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            accountStatus: true,
          },
        },
        assignments: {
          select: {
            id: true,
            vehicleId: true,
            driverId: true,
            assignmentStatus: true,
          },
        },
      },
    });

    const now = Date.now();
    return {
      items: rows.map((g) => {
        const requested = fleetQuantities(g.requestedFleetItems);
        const fleetRequested = requested.reduce((s, l) => s + l.quantity, 0);
        const chauffeurs = g.assignments.filter((a) => a.driverId != null).length;
        return {
          id: g.id,
          reference_code: g.referenceCode,
          status: g.status,
          ceremony_type: g.ceremonyType,
          city: g.city,
          service_start_time: g.serviceStartTime,
          service_end_time: g.serviceEndTime,
          created_at: g.createdAt,
          age_minutes: Math.floor((now - g.createdAt.getTime()) / 60_000),
          customer: {
            id: g.customer.id,
            name: g.customer.fullName,
            phone: g.customer.phoneNumber,
            account_status: g.customer.accountStatus,
          },
          communication_preference: g.communicationPreference,
          passenger_count: g.passengerCount,
          fleet_requested: fleetRequested,
          fleet_assigned: g.assignments.length,
          chauffeurs_assigned: chauffeurs,
          chauffeurs_missing: g.assignments.length - chauffeurs,
          quote_pending: g.estimatedTotalPaise == null,
          estimated_total_paise: g.estimatedTotalPaise?.toString() ?? null,
          requirements: g.requirements ?? [],
          awaiting:
            g.status === BookingStatus.CUSTOMER_CONFIRMATION_PENDING
              ? 'CUSTOMER'
              : chauffeurs < g.assignments.length
                ? 'OPERATIONS_CHAUFFEUR'
                : 'OPERATIONS',
          version: g.version,
        };
      }),
      total: rows.length,
    };
  }

  // -------------------------------------------------------------- workspace

  /**
   * The full operational picture for ONE booking: who the customer is and how
   * to reach them, what they asked for, what is actually allocated (vehicle,
   * owning partner, chauffeur, paperwork state), the frozen price, the calendar
   * locks, the internal notes and the complete status history.
   */
  async bookingWorkspace(id: string) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id },
      include: {
        customer: {
          select: {
            id: true,
            fullName: true,
            phoneNumber: true,
            email: true,
            accountStatus: true,
            customerProfile: { select: { preferredLanguage: true } },
          },
        },
        assignments: {
          orderBy: { sequenceNumber: 'asc' },
          include: {
            vehicle: {
              include: {
                vehicleType: { select: { displayName: true, vehicleClass: true } },
                fleetOwner: {
                  select: {
                    id: true,
                    companyName: true,
                    contactName: true,
                    verificationStatus: true,
                    user: { select: { phoneNumber: true } },
                  },
                },
                documents: {
                  select: { documentType: true, verificationStatus: true, expiryDate: true },
                },
              },
            },
            driver: {
              include: {
                user: { select: { fullName: true, phoneNumber: true } },
                documents: {
                  select: { documentType: true, verificationStatus: true, expiryDate: true },
                },
              },
            },
          },
        },
        operationsNotes: {
          orderBy: { createdAt: 'desc' },
          include: { author: { select: { id: true, fullName: true, primaryRole: true } } },
        },
        events: {
          orderBy: { createdAt: 'asc' },
          include: { actor: { select: { id: true, fullName: true, primaryRole: true } } },
        },
        bookings: { select: { id: true, status: true } },
      },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }

    const locks = await this.prisma.availability.findMany({
      where: {
        OR: [
          { vehicleId: { in: group.assignments.map((a) => a.vehicleId) } },
          {
            driverId: {
              in: group.assignments
                .map((a) => a.driverId)
                .filter((d): d is string => d != null),
            },
          },
        ],
        status: 'BOOKED',
      },
      select: { id: true, vehicleId: true, driverId: true, startTime: true, endTime: true },
    });

    return {
      id: group.id,
      reference_code: group.referenceCode,
      status: group.status,
      version: group.version,
      created_at: group.createdAt,
      updated_at: group.updatedAt,

      customer: {
        id: group.customer.id,
        name: group.customer.fullName,
        phone: group.customer.phoneNumber,
        email: group.customer.email,
        account_status: group.customer.accountStatus,
        preferred_language: group.customer.customerProfile?.preferredLanguage ?? null,
      },
      communication_preference: group.communicationPreference,

      request: {
        ceremony_type: group.ceremonyType,
        city: group.city,
        pickup_address: group.pickupAddress,
        destination_address: group.destinationAddress,
        service_start_time: group.serviceStartTime,
        service_end_time: group.serviceEndTime,
        passenger_count: group.passengerCount,
        requirements: group.requirements ?? [],
        requested_fleet_items: group.requestedFleetItems ?? [],
      },

      quote: {
        pending: group.estimatedTotalPaise == null,
        estimated_total_paise: group.estimatedTotalPaise?.toString() ?? null,
        advance_token_paise: group.advanceTokenPaise?.toString() ?? null,
        snapshot: group.pricingSnapshot ?? null,
      },

      // Full internal allocation — vehicle + owning partner + chauffeur.
      assignments: group.assignments.map((a) => ({
        id: a.id,
        sequence_number: a.sequenceNumber,
        requested_model: a.requestedModel,
        assignment_status: a.assignmentStatus,
        estimated_total_paise: a.estimatedTotalPaise?.toString() ?? null,
        advance_token_paise: a.advanceTokenPaise?.toString() ?? null,
        pricing_snapshot: a.pricingSnapshot ?? null,
        assigned_at: a.assignedAt,
        accepted_at: a.acceptedAt,
        declined_at: a.declinedAt,
        decline_reason: a.declineReason,
        vehicle: {
          id: a.vehicle.id,
          fleet_code: a.vehicle.fleetCode,
          registration_number: a.vehicle.registrationNumber,
          display_name: a.vehicle.vehicleType?.displayName ?? null,
          vehicle_class: a.vehicle.vehicleType?.vehicleClass ?? null,
          color: a.vehicle.color,
          year: a.vehicle.yearOfManufacture,
          city: a.vehicle.city,
          verification_status: a.vehicle.verificationStatus,
          is_active: a.vehicle.isActive,
          is_available: a.vehicle.isAvailable,
          documents: a.vehicle.documents.map((d) => ({
            type: d.documentType,
            status: d.verificationStatus,
            expires_at: d.expiryDate,
          })),
        },
        partner: a.vehicle.fleetOwner
          ? {
              id: a.vehicle.fleetOwner.id,
              company_name: a.vehicle.fleetOwner.companyName,
              contact_name: a.vehicle.fleetOwner.contactName,
              phone: a.vehicle.fleetOwner.user?.phoneNumber ?? null,
              verification_status: a.vehicle.fleetOwner.verificationStatus,
            }
          : null,
        chauffeur: a.driver
          ? {
              id: a.driver.id,
              name: a.driver.user?.fullName ?? null,
              phone: a.driver.user?.phoneNumber ?? null,
              licence_number: a.driver.licenseNumber,
              experience_years: a.driver.experienceYears,
              languages: a.driver.languagesSpoken,
              verification_status: a.driver.verificationStatus,
              duty_status: a.driver.dutyStatus,
              documents: a.driver.documents.map((d) => ({
                type: d.documentType,
                status: d.verificationStatus,
                expires_at: d.expiryDate,
              })),
            }
          : null,
      })),

      calendar_locks: locks.map((l) => ({
        id: l.id,
        vehicle_id: l.vehicleId,
        driver_id: l.driverId,
        start_time: l.startTime,
        end_time: l.endTime,
      })),

      linked_bookings: group.bookings.map((b) => ({ id: b.id, status: b.status })),

      internal_notes: group.operationsNotes.map((n) => ({
        id: n.id,
        body: n.body,
        author: { id: n.author.id, name: n.author.fullName, role: n.author.primaryRole },
        created_at: n.createdAt,
      })),

      history: group.events.map((e) => ({
        id: e.id,
        from_status: e.fromStatus,
        to_status: e.toStatus,
        action: e.action,
        reason: e.eventReason,
        actor: { id: e.actor.id, name: e.actor.fullName, role: e.triggerRole },
        created_at: e.createdAt,
      })),
    };
  }

  // ------------------------------------------------------------- lifecycle

  /**
   * Operations moves the request forward. Legality is decided by the shared
   * booking state machine against the ADMIN's actual role — a
   * verificationAdmin or financeAdmin token cannot drive the operations path,
   * and the transition table (not this service) is the single source of truth.
   */
  async transition(id: string, dto: OperationsTransitionDto, admin: AuthenticatedUser) {
    const group = await this.requireBooking(id);

    if ((dto.action === 'CANCEL' || dto.action === 'EXPIRE') && !dto.reason?.trim()) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        `A reason is required to ${dto.action.toLowerCase()} a booking request.`,
      );
    }

    // Operations may only confirm once every reserved vehicle is in a
    // customer-promisable state AND a chauffeur exists for each one — the
    // customer is being asked to agree to a concrete fleet, not an intention.
    // The rule lives on the shared service so the customer's own confirm tap
    // is bound by exactly the same check.
    if (dto.action === 'CONFIRM_BOOKING') {
      await this.groupBookings.assertConfirmable(id);
    }

    const target = this.stateMachine.assertTransitionAllowed(
      group.status as BookingStatus,
      dto.action,
      admin.role as ActorRole,
    );

    return this.groupBookings.applyTransition({
      group,
      target,
      action: dto.action,
      actorUserId: admin.userId,
      actorRole: admin.role,
      reason: dto.reason,
    });
  }

  /**
   * Records a customer contact attempt. Stored as an internal note (so it sits
   * with the booking's operational context) plus an audit row, and can advance
   * the booking to CUSTOMER_CONFIRMATION_PENDING — the moment the managed model
   * says responsibility crosses back to the customer.
   */
  async logCustomerContact(id: string, dto: LogCustomerContactDto, admin: AuthenticatedUser) {
    const group = await this.requireBooking(id);
    const entry = [
      `Customer contact via ${dto.channel}: ${dto.outcome}`,
      dto.note ? `— ${dto.note}` : '',
    ]
      .join(' ')
      .trim();

    const note = await this.prisma.operationsNote.create({
      data: { groupBookingId: id, authorUserId: admin.userId, body: entry },
    });
    await this.audit(admin, 'CUSTOMER_CONTACT_LOGGED', id, {
      channel: dto.channel,
      outcome: dto.outcome,
      advanced: dto.advanceToConfirmation === true,
    });

    let transition: unknown = null;
    if (dto.advanceToConfirmation) {
      transition = await this.transition(
        id,
        { action: 'REQUEST_CUSTOMER_CONFIRMATION' },
        admin,
      );
    }
    return {
      note_id: note.id,
      booking_status: dto.advanceToConfirmation ? BookingStatus.CUSTOMER_CONFIRMATION_PENDING : group.status,
      transition,
    };
  }

  // ------------------------------------------------------------------ notes

  async addNote(id: string, body: string, admin: AuthenticatedUser) {
    await this.requireBooking(id);
    const note = await this.prisma.operationsNote.create({
      data: { groupBookingId: id, authorUserId: admin.userId, body },
      include: { author: { select: { id: true, fullName: true, primaryRole: true } } },
    });
    await this.audit(admin, 'OPERATIONS_NOTE_ADDED', id, { noteId: note.id });
    return {
      id: note.id,
      body: note.body,
      author: { id: note.author.id, name: note.author.fullName, role: note.author.primaryRole },
      created_at: note.createdAt,
    };
  }

  // ------------------------------------------------------------ allocation

  /**
   * Swap the concrete vehicle reserved for an assignment.
   *
   * Guarded because this is the single riskiest operation: a vehicle already
   * committed elsewhere must never be double-allocated, and the customer must
   * never be handed a different car without the change being recorded. The
   * replacement is checked against the same public eligibility rules the
   * catalog uses (verified + active + available) and against the calendar.
   */
  async reallocateVehicle(
    assignmentId: string,
    vehicleId: string,
    admin: AuthenticatedUser,
    reason?: string,
  ) {
    const assignment = await this.prisma.vehicleAssignment.findUnique({
      where: { id: assignmentId },
      include: { groupBooking: true },
    });
    if (!assignment) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
    }
    if (!assignment.groupBooking) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This assignment is not part of a group booking.',
      );
    }
    if (assignment.vehicleId === vehicleId) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'That vehicle is already allocated to this assignment.',
      );
    }

    const replacement = await this.prisma.vehicle.findUnique({ where: { id: vehicleId } });
    if (!replacement) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Replacement vehicle not found.');
    }
    if (replacement.verificationStatus !== 'APPROVED' || !replacement.isActive) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'Only a verified, active vehicle can be allocated to a customer booking.',
      );
    }

    const group = assignment.groupBooking;
    return this.prisma.$transaction(async (tx) => {
      const clash = await tx.availability.findFirst({
        where: {
          vehicleId,
          status: 'BOOKED',
          startTime: { lt: group.serviceEndTime },
          endTime: { gt: group.serviceStartTime },
        },
      });
      if (clash) {
        throw new ConflictAppException(
          ErrorCode.SLOT_DOUBLE_BOOKED,
          'That vehicle is already committed for an overlapping window.',
        );
      }
      // Release the old reservation window and take the new one atomically.
      await tx.availability.deleteMany({
        where: {
          vehicleId: assignment.vehicleId,
          bookingId: null,
          status: 'BOOKED',
          startTime: { lt: group.serviceEndTime },
          endTime: { gt: group.serviceStartTime },
        },
      });
      await tx.availability.create({
        data: {
          vehicleId,
          startTime: group.serviceStartTime,
          endTime: group.serviceEndTime,
          status: 'BOOKED',
        },
      });

      const updated = await tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          vehicleId,
          // Changing the car invalidates a previous vehicle confirmation: the
          // act of re-allocating IS operations confirming a vehicle, so the
          // assignment lands on VEHICLE_CONFIRMED and keeps its chauffeur.
          assignmentStatus: AssignmentStatus.VEHICLE_CONFIRMED,
          assignedByUserId: admin.userId,
          assignedAt: new Date(),
        },
      });

      await tx.auditLog.create({
        data: {
          actorId: admin.userId,
          actorRole: admin.role,
          action: 'VEHICLE_REALLOCATED',
          targetEntity: 'vehicle_assignments',
          targetId: assignmentId,
          changes: {
            groupBookingId: group.id,
            from_vehicle_id: assignment.vehicleId,
            to_vehicle_id: vehicleId,
            reason: reason ?? null,
          },
        },
      });

      return {
        assignment_id: updated.id,
        vehicle_id: updated.vehicleId,
        assignment_status: updated.assignmentStatus,
      };
    });
  }

  /** Releases the chauffeur from an assignment so operations can re-assign. */
  async unassignChauffeur(assignmentId: string, admin: AuthenticatedUser) {
    const assignment = await this.prisma.vehicleAssignment.findUnique({
      where: { id: assignmentId },
      include: { groupBooking: true },
    });
    if (!assignment) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
    }
    if (!assignment.driverId) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'No chauffeur is assigned to this vehicle.',
      );
    }
    const previousDriverId = assignment.driverId;
    return this.prisma.$transaction(async (tx) => {
      if (assignment.groupBooking) {
        await tx.availability.deleteMany({
          where: {
            driverId: previousDriverId,
            bookingId: null,
            status: 'BOOKED',
            startTime: { lt: assignment.groupBooking.serviceEndTime },
            endTime: { gt: assignment.groupBooking.serviceStartTime },
          },
        });
      }
      const updated = await tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: {
          driverId: null,
          assignmentStatus: AssignmentStatus.VEHICLE_CONFIRMED,
          acceptedAt: null,
        },
      });
      await tx.auditLog.create({
        data: {
          actorId: admin.userId,
          actorRole: admin.role,
          action: 'CHAUFFEUR_UNASSIGNED',
          targetEntity: 'vehicle_assignments',
          targetId: assignmentId,
          changes: { previous_driver_id: previousDriverId },
        },
      });
      return {
        assignment_id: updated.id,
        driver_id: updated.driverId,
        assignment_status: updated.assignmentStatus,
      };
    });
  }

  /**
   * Chauffeurs operations can actually assign to this assignment's window:
   * verified, on the platform, and NOT already committed to an overlapping
   * booking. Partner-affiliated chauffeurs are listed with their partner so the
   * desk can prefer the fleet that owns the vehicle.
   */
  async availableChauffeurs(assignmentId: string) {
    const assignment = await this.prisma.vehicleAssignment.findUnique({
      where: { id: assignmentId },
      include: { groupBooking: true, vehicle: true },
    });
    if (!assignment?.groupBooking) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
    }
    const group = assignment.groupBooking;

    const busy = await this.prisma.availability.findMany({
      where: {
        driverId: { not: null },
        status: 'BOOKED',
        startTime: { lt: group.serviceEndTime },
        endTime: { gt: group.serviceStartTime },
      },
      select: { driverId: true },
    });
    const busyIds = new Set(busy.map((b) => b.driverId as string));

    const drivers = await this.prisma.driverProfile.findMany({
      where: { verificationStatus: 'APPROVED' },
      include: {
        user: { select: { fullName: true, phoneNumber: true, accountStatus: true } },
        fleetOwner: { select: { id: true, companyName: true } },
      },
      orderBy: { totalTripsCompleted: 'desc' },
      take: 50,
    });

    return {
      service_start_time: group.serviceStartTime,
      service_end_time: group.serviceEndTime,
      items: drivers
        .filter((d) => !busyIds.has(d.id))
        .map((d) => ({
          id: d.id,
          name: d.user?.fullName ?? null,
          phone: d.user?.phoneNumber ?? null,
          account_status: d.user?.accountStatus ?? null,
          experience_years: d.experienceYears,
          languages: d.languagesSpoken,
          average_rating: Number(d.averageRating),
          total_trips_completed: d.totalTripsCompleted,
          duty_status: d.dutyStatus,
          partner: d.fleetOwner
            ? { id: d.fleetOwner.id, company_name: d.fleetOwner.companyName }
            : null,
          /** Same partner as the vehicle is usually the cheapest coordination. */
          same_partner_as_vehicle: d.fleetOwnerId === assignment.vehicle.fleetOwnerId,
        })),
      total: drivers.filter((d) => !busyIds.has(d.id)).length,
    };
  }

  /**
   * Re-quote from the vehicles actually allocated now, using each vehicle's
   * newest APPROVED tariff. This is how operations produces the FINAL price it
   * quotes the customer on the phone — the earlier auto-quote is only
   * indicative. Nothing is overwritten: a new snapshot supersedes the previous
   * one and the superseded snapshot is retained in the audit trail.
   */
  async requote(id: string, dto: RequoteDto, admin: AuthenticatedUser) {
    const group = await this.prisma.groupBooking.findUnique({
      where: { id },
      include: { assignments: { include: { vehicle: true }, orderBy: { sequenceNumber: 'asc' } } },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    if (group.assignments.length === 0) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'There is nothing to quote yet — no vehicles are allocated.',
      );
    }

    const hours = serviceHours(group.serviceStartTime, group.serviceEndTime);
    const overnight = crossesMidnight(group.serviceStartTime, group.serviceEndTime);
    const routeDistanceKm = dto.routeDistanceKm ?? null;

    const lines: Array<Record<string, unknown>> = [];
    const unpriced: string[] = [];
    let total = 0n;

    for (const assignment of group.assignments) {
      const tariff = await this.prisma.vehiclePricing.findFirst({
        where: { vehicleId: assignment.vehicleId, status: 'APPROVED' },
        orderBy: { version: 'desc' },
      });
      const quote = deriveLineQuote(tariff, hours, overnight);

      // Optional distance surcharge: km beyond the tariff's included package,
      // billed at the per-km rate. Only ever ADDS to a real package amount —
      // an unpriced line stays unpriced rather than inventing a base.
      let surchargePaise = 0n;
      let billableKm: number | null = null;
      if (routeDistanceKm != null && tariff?.perKmPaise != null && quote.amountPaise != null) {
        const included = tariff.localIncludedKm ?? 0;
        billableKm = Math.max(0, routeDistanceKm - included);
        surchargePaise = tariff.perKmPaise * BigInt(billableKm);
      }

      const lineAmount = quote.amountPaise == null ? null : quote.amountPaise + surchargePaise;
      if (lineAmount == null) unpriced.push(assignment.vehicleId);
      else total += lineAmount;

      await this.prisma.vehicleAssignment.update({
        where: { id: assignment.id },
        data: {
          estimatedTotalPaise: lineAmount,
          advanceTokenPaise: lineAmount != null ? advanceFor(lineAmount) : null,
          pricingSnapshot: {
            source: 'OPS_REQUOTE',
            quoted_at: new Date().toISOString(),
            quoted_by_user_id: admin.userId,
            service_hours: hours,
            crosses_midnight: overnight,
            basis: quote.basis,
            base_paise: quote.amountPaise?.toString() ?? null,
            route_distance_km: routeDistanceKm,
            billable_km: billableKm,
            per_km_paise: tariff?.perKmPaise?.toString() ?? null,
            surcharge_paise: surchargePaise.toString(),
            amount_paise: lineAmount?.toString() ?? null,
            tariff_version: quote.tariffVersion ?? null,
            tariff_id: quote.tariffId ?? null,
          } as unknown as Prisma.InputJsonValue,
        },
      });

      lines.push({
        assignment_id: assignment.id,
        vehicle_id: assignment.vehicleId,
        fleet_code: assignment.vehicle.fleetCode,
        basis: quote.basis,
        base_paise: quote.amountPaise?.toString() ?? null,
        surcharge_paise: surchargePaise.toString(),
        amount_paise: lineAmount?.toString() ?? null,
        tariff_version: quote.tariffVersion ?? null,
      });
    }

    const complete = unpriced.length === 0;
    const totalPaise = complete ? total : null;
    const advancePaise = totalPaise != null ? advanceFor(totalPaise) : null;
    const previousSnapshot = group.pricingSnapshot as Prisma.JsonValue | null;

    const updated = await this.prisma.groupBooking.update({
      where: { id },
      data: {
        estimatedTotalPaise: totalPaise,
        advanceTokenPaise: advancePaise,
        pricingSnapshot: {
          source: 'OPS_REQUOTE',
          quoted_at: new Date().toISOString(),
          quoted_by_user_id: admin.userId,
          complete,
          supersedes: previousSnapshot ?? null,
          service_hours: hours,
          crosses_midnight: overnight,
          route_distance_km: routeDistanceKm,
          total_paise: totalPaise?.toString() ?? null,
          advance_paise: advancePaise?.toString() ?? null,
          unpriced_vehicle_ids: unpriced,
          lines,
          reason: dto.reason ?? null,
        } as unknown as Prisma.InputJsonValue,
        version: { increment: 1 },
      },
    });

    await this.audit(admin, 'BOOKING_REQUOTED', id, {
      complete,
      total_paise: totalPaise?.toString() ?? null,
      route_distance_km: routeDistanceKm,
      unpriced_vehicle_ids: unpriced,
    });

    return {
      id: updated.id,
      // Reported from the COMPUTED values, not from a re-read of the row: the
      // response must describe the quote that was just derived.
      quote_pending: totalPaise == null,
      estimated_total_paise: totalPaise?.toString() ?? null,
      advance_token_paise: advancePaise?.toString() ?? null,
      lines,
      unpriced_vehicle_ids: unpriced,
    };
  }

  // ----------------------------------------------------------------- helpers

  private async requireBooking(id: string) {
    const group = await this.prisma.groupBooking.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    return group;
  }

  private async audit(
    admin: AuthenticatedUser,
    action: string,
    groupBookingId: string,
    changes: Prisma.InputJsonValue,
  ) {
    await this.prisma.auditLog.create({
      data: {
        actorId: admin.userId,
        actorRole: admin.role,
        action,
        targetEntity: 'group_bookings',
        targetId: groupBookingId,
        changes,
      },
    });
  }
}

/** Normalises the persisted fleet intent into {vehicleTypeId, quantity} lines. */
function fleetQuantities(raw: unknown): Array<{ vehicleTypeId: string; quantity: number }> {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((line) => {
      const record = line as { vehicleTypeId?: unknown; quantity?: unknown };
      return {
        vehicleTypeId: String(record.vehicleTypeId ?? ''),
        quantity: Number(record.quantity ?? 0),
      };
    })
    .filter((l) => l.vehicleTypeId.length > 0 && Number.isFinite(l.quantity));
}

