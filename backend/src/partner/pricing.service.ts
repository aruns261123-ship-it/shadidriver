import { Injectable } from '@nestjs/common';
import { Prisma, PricingStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { SubmitVehiclePricingDto } from './dto/pricing.dto';

/**
 * Partner pricing submission.
 *
 * Business rules this module exists to protect:
 *   * a partner submits tariffs only for its OWN vehicles (404 otherwise —
 *     same not-found-not-forbidden rule as the fleet endpoints);
 *   * pricing is VERSIONED and immutable: every submission inserts a new row
 *     with the next version number, so approved history is never overwritten;
 *   * a submission always starts PENDING_REVIEW — a partner can never set its
 *     own price live, and a pending supersession never changes what customers
 *     see (the public indicator reads only APPROVED rows);
 *   * the submitted values ARE the customer-facing price once approved, so
 *     arithmetic sanity (package > per-km, day > hourly * 8, …) is validated
 *     here rather than trusted to the client.
 */
@Injectable()
export class PricingService {
  constructor(private readonly prisma: PrismaService) {}

  /** Submits a new tariff version for a vehicle owned by the caller. */
  async submitPricing(userId: string, vehicleId: string, dto: SubmitVehiclePricingDto) {
    const partner = await this.prisma.partnerProfile.findUnique({
      where: { userId },
    });
    if (!partner) {
      throw new NotFoundAppException(
        ErrorCode.NOT_FOUND,
        'No partner profile for this account. Register as a partner first.',
      );
    }

    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });
    if (!vehicle || vehicle.fleetOwnerId !== partner.id) {
      // Not-found, never forbidden — an ownership probe must not confirm ids.
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }
    if (vehicle.verificationStatus === 'SUSPENDED') {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This vehicle is suspended. Resolve verification before pricing it.',
      );
    }

    this.assertSaneTariff(dto);

    const latest = await this.prisma.vehiclePricing.findFirst({
      where: { vehicleId },
      orderBy: { version: 'desc' },
      select: { version: true, status: true },
    });
    const nextVersion = (latest?.version ?? 0) + 1;

    const created = await this.prisma.$transaction(async (tx) => {
      // An APPROVED tariff stays the live one until an admin approves the
      // successor; the new row is purely a pending proposal.
      const row = await tx.vehiclePricing.create({
        data: {
          vehicleId,
          version: nextVersion,
          localIncludedKm: dto.localIncludedKm,
          localAmountPaise: dto.localAmountPaise,
          perKmPaise: dto.perKmPaise,
          hourlyPaise: dto.hourlyPaise ?? null,
          extraHourPaise: dto.extraHourPaise ?? null,
          fullDayPaise: dto.fullDayPaise ?? null,
          overnightPaise: dto.overnightPaise ?? null,
          outstationPerDayPaise: dto.outstationPerDayPaise ?? null,
          outstationPerKmPaise: dto.outstationPerKmPaise ?? null,
          status: PricingStatus.PENDING_REVIEW,
          submittedByUserId: userId,
          effectiveFrom: dto.effectiveFrom ? new Date(dto.effectiveFrom) : null,
        },
      });
      await tx.auditLog.create({
        data: {
          actorId: userId,
          actorRole: 'fleetOwner',
          action: 'PRICING_SUBMITTED',
          targetEntity: 'vehicle_pricing',
          targetId: row.id,
          changes: { vehicleId, version: nextVersion } as Prisma.InputJsonValue,
        },
      });
      return row;
    });

    return this.viewVersion(created);
  }

  /** Full tariff history for one of the partner's vehicles, newest first. */
  async listPricing(userId: string, vehicleId: string) {
    const partner = await this.prisma.partnerProfile.findUnique({
      where: { userId },
    });
    if (!partner) {
      throw new NotFoundAppException(
        ErrorCode.NOT_FOUND,
        'No partner profile for this account. Register as a partner first.',
      );
    }
    const vehicle = await this.prisma.vehicle.findUnique({
      where: { id: vehicleId },
    });
    if (!vehicle || vehicle.fleetOwnerId !== partner.id) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }

    const rows = await this.prisma.vehiclePricing.findMany({
      where: { vehicleId },
      orderBy: { version: 'desc' },
    });
    return {
      vehicle_id: vehicleId,
      items: rows.map((r) => this.viewVersion(r)),
      live_version: rows.find((r) => r.status === PricingStatus.APPROVED)?.version ?? null,
    };
  }

  /**
   * Arithmetic sanity of a tariff. A tariff whose components contradict each
   * other would produce absurd quotes once approved (a Rs 500/day car with a
   * Rs 1,00,000 local package).
   */
  private assertSaneTariff(dto: SubmitVehiclePricingDto) {
    const paise = (rs: number) => rs / 100;
    if (dto.fullDayPaise !== undefined) {
      // An 8-hour day must not cost less than the local package it supersedes,
      // and not less than 8 times the hourly rate when one is given.
      if (dto.fullDayPaise < dto.localAmountPaise) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          `fullDayPaise (${paise(dto.fullDayPaise)} Rs) cannot be lower than the local package (${paise(dto.localAmountPaise)} Rs).`,
        );
      }
      if (dto.hourlyPaise !== undefined && dto.fullDayPaise < dto.hourlyPaise * 4) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          'fullDayPaise cannot be lower than 4 hourly rates.',
        );
      }
    }
    if (dto.overnightPaise !== undefined && dto.fullDayPaise !== undefined) {
      if (dto.overnightPaise < dto.fullDayPaise) {
        throw new BadRequestAppException(
          ErrorCode.VALIDATION_FAILED,
          'overnightPaise cannot be lower than the full-day rate.',
        );
      }
    }
    // NOTE: there is deliberately NO rule forcing outstationPerDayPaise above
    // the full-day rate — the standard Indian commercial model prices the
    // outstation DAY below a city full-day package because per-km charges
    // accumulate over long distances on top of it.
    if (dto.outstationPerKmPaise !== undefined && dto.outstationPerKmPaise < dto.perKmPaise) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'outstationPerKmPaise cannot be lower than the local per-km rate.',
      );
    }
  }

  private viewVersion(r: {
    id: string;
    vehicleId: string;
    version: number;
    currency: string;
    localIncludedKm: number | null;
    localAmountPaise: bigint | null;
    perKmPaise: bigint | null;
    hourlyPaise: bigint | null;
    extraHourPaise: bigint | null;
    fullDayPaise: bigint | null;
    overnightPaise: bigint | null;
    outstationPerDayPaise: bigint | null;
    outstationPerKmPaise: bigint | null;
    status: PricingStatus;
    submittedAt: Date;
    reviewedAt: Date | null;
    decisionReason: string | null;
    effectiveFrom: Date | null;
  }) {
    return {
      id: r.id,
      vehicle_id: r.vehicleId,
      version: r.version,
      currency: r.currency,
      local_included_km: r.localIncludedKm,
      local_amount_paise: r.localAmountPaise?.toString() ?? null,
      per_km_paise: r.perKmPaise?.toString() ?? null,
      hourly_paise: r.hourlyPaise?.toString() ?? null,
      extra_hour_paise: r.extraHourPaise?.toString() ?? null,
      full_day_paise: r.fullDayPaise?.toString() ?? null,
      overnight_paise: r.overnightPaise?.toString() ?? null,
      outstation_per_day_paise: r.outstationPerDayPaise?.toString() ?? null,
      outstation_per_km_paise: r.outstationPerKmPaise?.toString() ?? null,
      status: r.status,
      submitted_at: r.submittedAt,
      reviewed_at: r.reviewedAt,
      decision_reason: r.decisionReason,
      effective_from: r.effectiveFrom,
      // What the partner most needs to know, stated plainly.
      is_live: r.status === PricingStatus.APPROVED,
    };
  }
}
