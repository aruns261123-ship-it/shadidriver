import { Injectable } from '@nestjs/common';
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
      const assignmentsData: Array<{
        vehicleId: string;
        driverId: string;
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
        const candidates = await tx.vehicle.findMany({
          where: {
            vehicleTypeId: line.vehicleTypeId,
            verificationStatus: 'APPROVED',
            isActive: true,
            isAvailable: true,
            city: { contains: input.city, mode: 'insensitive' },
          },
          include: { independentDriver: true },
          take: line.quantity * 3,
        });
        const eligible = candidates.filter(
          (v) => !allocatedIds.has(v.id) && v.independentDriver !== null,
        );
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
            driverId: vehicle.independentDriver!.id,
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
          passengerCount: input.passengerCount,
          estimatedTotalPaise: subtotalPaise,
          advanceTokenPaise: totalAdvance,
          status: BookingStatus.REQUESTED,
          idempotencyKey: idemKey,
        },
      });

      await tx.vehicleAssignment.createMany({
        data: assignmentsData.map((a) => ({ ...a, groupBookingId: group.id })),
      });

      // Calendar locks for every allocated vehicle+driver window.
      await tx.availability.createMany({
        data: assignmentsData.map((a) => ({
          driverId: a.driverId,
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
          include: {
            vehicle: { include: { vehicleType: true } },
            driver: { include: { user: { select: { fullName: true, phoneNumber: true } } } },
          },
          orderBy: { sequenceNumber: 'asc' },
        },
        serviceCategory: true,
      },
    });
    if (!group) {
      throw new NotFoundAppException(ErrorCode.GROUP_BOOKING_NOT_FOUND, 'Group booking not found.');
    }
    return {
      ...group,
      assignments: group.assignments.map((a) => ({
        id: a.id,
        sequence_number: a.sequenceNumber,
        status: a.status,
        vehicle: {
          id: a.vehicle.id,
          display_name: a.vehicle.vehicleType.displayName,
          fleet_code: a.vehicle.fleetCode,
          registration_number: a.vehicle.registrationNumber,
        },
        chauffeur: {
          id: a.driver.userId,
          full_name: a.driver.user.fullName,
          phone: a.driver.user.phoneNumber,
          verification_status: a.driver.verificationStatus,
        },
        estimated_total_paise: a.estimatedTotalPaise.toString(),
        advance_token_paise: a.advanceTokenPaise.toString(),
        requested_model: a.requestedModel,
      })),
    };
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
      status: a.status,
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

  /** Driver accept for a group assignment (transactional, mirrors single accept). */
  async acceptAssignment(assignmentId: string, driverUserId: string) {
    const driver = await this.prisma.driverProfile.findUnique({
      where: { userId: driverUserId },
    });
    if (!driver) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Driver profile not found.');
    }
    if (driver.verificationStatus !== 'APPROVED') {
      throw new ConflictAppException(
        ErrorCode.ROLE_FORBIDDEN,
        'Only verified chauffeurs can accept assignments.',
      );
    }
    return this.prisma.$transaction(async (tx) => {
      const locked = await tx.$queryRaw<{ id: string; status: string; group_booking_id: string | null }[]>`
        SELECT "id", "status", "group_booking_id" FROM "vehicle_assignments"
        WHERE "id" = ${assignmentId} FOR UPDATE`;
      if (!locked?.length) {
        throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Assignment not found.');
      }
      if (locked[0].status !== BookingStatus.REQUESTED) {
        throw new ConflictAppException(
          ErrorCode.SLOT_DOUBLE_BOOKED,
          'This assignment was already resolved by another chauffeur.',
        );
      }
      const updated = await tx.vehicleAssignment.update({
        where: { id: assignmentId },
        data: { status: BookingStatus.DRIVER_ACCEPTED, driverId: driver.id, acceptedAt: new Date() },
      });

      // Parent status: stays REQUESTED until ALL assignments are accepted
      // (then DRIVER_ACCEPTED = convoy ready); mixed states stay REQUESTED
      // until the payment milestone. Terminal states propagate upward.
      const groupId = locked[0].group_booking_id as string;
      const all = await tx.vehicleAssignment.findMany({
        where: { groupBookingId: groupId },
        select: { status: true },
      });
      const allAccepted = all.every((a) => a.status === BookingStatus.DRIVER_ACCEPTED);
      const anyCancelled = all.some((a) => a.status === BookingStatus.CANCELLED);
      await tx.groupBooking.update({
        where: { id: groupId },
        data: {
          status: anyCancelled
            ? BookingStatus.CANCELLED
            : allAccepted
              ? BookingStatus.DRIVER_ACCEPTED
              : BookingStatus.REQUESTED,
          version: { increment: 1 },
        },
      });
      return updated;
    });
  }
}
