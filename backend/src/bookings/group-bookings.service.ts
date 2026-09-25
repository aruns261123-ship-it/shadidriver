import { Injectable } from '@nestjs/common';
import { AssignmentStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { BookingStatus } from '../booking-state-machine/booking-status';
import { AvailabilityService, FleetRequestLine } from '../availability/availability.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

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

      let subtotalPaise = 0n;
      // No chauffeur is bound at submit time. The customer requests vehicles;
      // ShadiDriver operations assigns chauffeurs internally afterwards, so a
      // reservation must never wait on (or be lost to) a driver offer loop.
      const assignmentsData: Array<{
        vehicleId: string;
        sequenceNumber: number;
        requestedModel: string;
        estimatedTotalPaise: bigint;
        advanceTokenPaise: bigint;
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
          const unitPrice = vehicle.basePricePaise;
          subtotalPaise += unitPrice;
          assignmentsData.push({
            vehicleId: vehicle.id,
            sequenceNumber: sequence++,
            requestedModel: type.displayName,
            estimatedTotalPaise: unitPrice,
            advanceTokenPaise: (unitPrice * 25n) / 100n,
          });
        }
      }

      const totalAdvance = assignmentsData.reduce((s, a) => s + a.advanceTokenPaise, 0n);

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
          estimatedTotalPaise: subtotalPaise,
          advanceTokenPaise: totalAdvance,
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

      return group;
    });

    return { groupBooking, idempotentReplay: false };
  }

  async getGroupBooking(id: string) {
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
    return serializeCustomerGroupBooking(group);
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
      const locked = await tx.$queryRaw<
        { id: string; assignment_status: string; group_booking_id: string | null }[]
      >`SELECT "id", "assignment_status", "group_booking_id" FROM "vehicle_assignments"
        WHERE "id" = ${assignmentId} FOR UPDATE`;
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
        if (everyAssigned) {
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
      FROM "vehicle_assignments" WHERE "id" = ${assignmentId} FOR UPDATE`;
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
  estimatedTotalPaise: bigint;
  advanceTokenPaise: bigint;
  requirements?: unknown;
  communicationPreference?: string;
  requestedFleetItems?: unknown;
  assignments: Array<{
    id: string;
    sequenceNumber: number;
    assignmentStatus: string;
    requestedModel: string | null;
    estimatedTotalPaise: bigint;
    advanceTokenPaise: bigint;
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
    estimated_total_paise: group.estimatedTotalPaise.toString(),
    advance_token_paise: group.advanceTokenPaise.toString(),
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
      estimated_total_paise: a.estimatedTotalPaise.toString(),
      advance_token_paise: a.advanceTokenPaise.toString(),
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
