import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { BadRequestAppException } from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

export interface FleetRequestLine {
  vehicleTypeId: string;
  quantity: number;
}

export interface FleetAvailabilityLine {
  vehicle_type_id: string;
  display_name: string;
  vehicle_class: string;
  requested: number;
  available: number;
  shortfall: number;
  /** Alternatives offered ONLY when there is a shortfall. Never a substitution. */
  alternatives: Array<{
    vehicle_type_id: string;
    display_name: string;
    vehicle_class: string;
    available: number;
    seating_capacity: number;
  }>;
  satisfied: boolean;
}

export interface FleetAvailabilityResult {
  service_start_time: string;
  service_end_time: string;
  duration_hours: number;
  city?: string;
  lines: FleetAvailabilityLine[];
  fully_available: boolean;
  total_requested: number;
  total_available: number;
  total_shortfall: number;
}

/**
 * Real availability engine. For every requested vehicle type we count the
 * VERIFIED + ACTIVE vehicles whose owners have not committed them to an
 * overlapping service window. Shortfalls are reported EXPLICITLY with
 * alternative suggestions — the engine never substitutes vehicles.
 *
 * Overlap semantics: existing BOOKED window [s,e] conflicts with a request
 * [start,end] iff s < end AND e > start (strict overlap; touching windows
 * do not conflict).
 */
@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  /** Vehicle IDs already allocated in an overlapping window. */
  private async allocatedVehicleIds(start: Date, end: Date): Promise<Set<string>> {
    const conflicts = await this.prisma.availability.findMany({
      where: {
        status: 'BOOKED',
        vehicleId: { not: null },
        startTime: { lt: end },
        endTime: { gt: start },
      },
      select: { vehicleId: true },
    });
    return new Set(conflicts.map((c) => c.vehicleId as string));
  }

  async checkFleetAvailability(
    lines: FleetRequestLine[],
    serviceStartTime: Date,
    serviceEndTime: Date,
    city?: string,
  ): Promise<FleetAvailabilityResult> {
    if (!lines || lines.length === 0) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'At least one vehicle type with quantity is required.',
      );
    }
    for (const line of lines) {
      if (!Number.isInteger(line.quantity) || line.quantity < 1 || line.quantity > 50) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          `Quantity for ${line.vehicleTypeId} must be between 1 and 50.`,
        );
      }
    }
    if (serviceEndTime <= serviceStartTime) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Service end time must be after start time.',
      );
    }

    const busyIds = await this.allocatedVehicleIds(serviceStartTime, serviceEndTime);
    const cityFilter = city ? { city: { contains: city, mode: 'insensitive' as const } } : {};

    const resultLines: FleetAvailabilityLine[] = [];
    for (const line of lines) {
      const type = await this.prisma.vehicleType.findUnique({
        where: { id: line.vehicleTypeId },
      });
      if (!type || !type.isActive) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          `Unknown vehicle type: ${line.vehicleTypeId}`,
        );
      }

      const fleet = await this.prisma.vehicle.findMany({
        where: {
          vehicleTypeId: line.vehicleTypeId,
          verificationStatus: 'APPROVED',
          isActive: true,
          isAvailable: true,
          ...cityFilter,
        },
        select: { id: true },
      });
      const available = fleet.filter((v) => !busyIds.has(v.id)).length;

      const shortage = Math.max(0, line.quantity - available);
      const lineResult: FleetAvailabilityLine = {
        vehicle_type_id: line.vehicleTypeId,
        display_name: type.displayName,
        vehicle_class: type.vehicleClass,
        requested: line.quantity,
        available,
        shortfall: shortage,
        alternatives: [],
        satisfied: shortage === 0,
      };

      // Alternatives only when there IS a shortfall; suggestions, never
      // substitutions. Prefer same class, then any type with enough capacity.
      if (shortage > 0) {
        const candidateTypes = await this.prisma.vehicleType.findMany({
          where: { isActive: true, id: { not: line.vehicleTypeId } },
        });
        const alternatives: FleetAvailabilityLine['alternatives'] = [];
        for (const candidate of candidateTypes) {
          const candidateFleet = await this.prisma.vehicle.findMany({
            where: {
              vehicleTypeId: candidate.id,
              verificationStatus: 'APPROVED',
              isActive: true,
              isAvailable: true,
              ...cityFilter,
            },
            select: { id: true },
          });
          const candidateAvailable = candidateFleet.filter((v) => !busyIds.has(v.id)).length;
          if (candidateAvailable >= shortage && candidate.seatingCap >= type.seatingCap) {
            alternatives.push({
              vehicle_type_id: candidate.id,
              display_name: candidate.displayName,
              vehicle_class: candidate.vehicleClass,
              available: candidateAvailable,
              seating_capacity: candidate.seatingCap,
            });
          }
        }
        lineResult.alternatives = alternatives
          .sort((a, b) => a.seating_capacity - b.seating_capacity)
          .slice(0, 3);
      }
      resultLines.push(lineResult);
    }

    return {
      service_start_time: serviceStartTime.toISOString(),
      service_end_time: serviceEndTime.toISOString(),
      duration_hours: Math.ceil(
        (serviceEndTime.getTime() - serviceStartTime.getTime()) / 3_600_000,
      ),
      city,
      lines: resultLines,
      fully_available: resultLines.every((l) => l.satisfied),
      total_requested: resultLines.reduce((s, l) => s + l.requested, 0),
      total_available: resultLines.reduce((s, l) => s + Math.min(l.available, l.requested), 0),
      total_shortfall: resultLines.reduce((s, l) => s + l.shortfall, 0),
    };
  }
}
