import { Injectable } from '@nestjs/common';
import { Prisma, VerificationStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { AuthenticatedUser } from '../auth/domain/auth.types';
import { DecisionAction } from './dto/admin.dto';

/**
 * Admin verification center.
 *
 * Every action here writes an AuditLog row — administrative decisions must be
 * reconstructable. Decisions on pending items are optimistic: the guard makes
 * these routes admin-only, and the queue makes review trivial.
 */
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ------------------------------------------------------------------ queues

  /** Partners awaiting review, oldest submission first. */
  async partnerQueue() {
    const partners = await this.prisma.partnerProfile.findMany({
      where: { verificationStatus: VerificationStatus.SUBMITTED },
      orderBy: { submittedAt: 'asc' },
      include: {
        user: { select: { phoneNumber: true, fullName: true } },
        vehicles: { select: { id: true, verificationStatus: true } },
      },
    });
    return {
      items: partners.map((p) => ({
        id: p.id,
        company_name: p.companyName,
        contact_name: p.contactName,
        phone: p.user?.phoneNumber ?? null,
        base_city: p.baseCity,
        service_cities: p.serviceCities,
        experience_years: p.experienceYears,
        license_number: p.licenseNumber,
        verification_status: p.verificationStatus,
        submitted_at: p.submittedAt,
        fleet_size: p.vehicles.length,
        fleet_pending: p.vehicles.filter((v) => v.verificationStatus !== 'APPROVED').length,
      })),
      total: partners.length,
    };
  }

  /** Vehicles awaiting verification, with their partner and paperwork state. */
  async vehicleQueue() {
    const vehicles = await this.prisma.vehicle.findMany({
      where: { verificationStatus: { in: [VerificationStatus.PENDING_SUBMISSION, VerificationStatus.UNDER_REVIEW, VerificationStatus.ACTION_REQUIRED] } },
      orderBy: { createdAt: 'asc' },
      include: {
        vehicleType: { select: { displayName: true, vehicleClass: true } },
        fleetOwner: {
          select: { id: true, companyName: true, verificationStatus: true },
        },
        documents: {
          select: { documentType: true, verificationStatus: true, expiryDate: true },
        },
      },
    });
    return {
      items: vehicles.map((v) => ({
        id: v.id,
        fleet_code: v.fleetCode,
        display_name: v.vehicleType?.displayName ?? null,
        vehicle_class: v.vehicleType?.vehicleClass ?? null,
        year: v.yearOfManufacture,
        registration_number: v.registrationNumber,
        color: v.color,
        city: v.city,
        verification_status: v.verificationStatus,
        partner: {
          id: v.fleetOwner?.id ?? null,
          company_name: v.fleetOwner?.companyName ?? null,
          verification_status: v.fleetOwner?.verificationStatus ?? null,
        },
        // Admin sees document readiness; a customer never does.
        documents: v.documents.map((d) => ({
          type: d.documentType,
          status: d.verificationStatus,
          expires_at: d.expiryDate,
        })),
      })),
      total: vehicles.length,
    };
  }

  /** Tariff versions awaiting commercial review, with the currently live one. */
  async pricingQueue() {
    const pending = await this.prisma.vehiclePricing.findMany({
      where: { status: 'PENDING_REVIEW' },
      orderBy: { submittedAt: 'asc' },
      include: {
        vehicle: {
          select: {
            fleetCode: true,
            registrationNumber: true,
            vehicleType: { select: { displayName: true } },
            fleetOwner: { select: { companyName: true } },
          },
        },
      },
    });

    const live = await this.prisma.vehiclePricing.findMany({
      where: {
        vehicleId: { in: pending.map((p) => p.vehicleId) },
        status: 'APPROVED',
      },
    });
    const liveByVehicle = new Map(live.map((l) => [l.vehicleId, l]));

    return {
      items: pending.map((p) => {
        const current = liveByVehicle.get(p.vehicleId);
        return {
          id: p.id,
          version: p.version,
          vehicle_id: p.vehicleId,
          fleet_code: p.vehicle?.fleetCode ?? null,
          vehicle: p.vehicle?.vehicleType?.displayName ?? null,
          partner: p.vehicle?.fleetOwner?.companyName ?? null,
          submitted_at: p.submittedAt,
          submitted: this.tariffView(p),
          currently_live: current ? this.tariffView(current) : null,
        };
      }),
      total: pending.length,
    };
  }

  // --------------------------------------------------------------- decisions

  /**
   * Decides a partner verification. APPROVE makes the PARTNER verified (never
   * its vehicles — each is verified separately). REJECT / REQUEST_CHANGES
   * require a reason, which is surfaced to the partner verbatim.
   */
  async decidePartner(admin: AuthenticatedUser, partnerId: string, action: DecisionAction, reason?: string) {
    const partner = await this.prisma.partnerProfile.findUnique({
      where: { id: partnerId },
    });
    if (!partner) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Partner not found.');
    }

    const status = this.statusFor(action, reason);
    const updated = await this.prisma.partnerProfile.update({
      where: { id: partnerId },
      data: {
        verificationStatus: status,
        reviewedAt: new Date(),
        decisionReason: reason ?? null,
      },
    });
    await this.audit(admin, 'PARTNER_VERIFICATION_DECIDED', 'fleet_owners', partnerId, {
      from: partner.verificationStatus,
      to: status,
      reason: reason ?? null,
    });
    return {
      id: updated.id,
      verification_status: updated.verificationStatus,
      decision_reason: updated.decisionReason,
      reviewed_at: updated.reviewedAt,
    };
  }

  /**
   * Decides a vehicle verification. Only APPROVE can make a vehicle bookable:
   * approving also flips the vehicle into the public catalog (APPROVED is the
   * eligibility rule the catalog enforces).
   */
  async decideVehicle(admin: AuthenticatedUser, vehicleId: string, action: DecisionAction, reason?: string) {
    const vehicle = await this.prisma.vehicle.findUnique({ where: { id: vehicleId } });
    if (!vehicle) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }

    const status = this.statusFor(action, reason);
    const updated = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { verificationStatus: status },
    });
    await this.audit(admin, 'VEHICLE_VERIFICATION_DECIDED', 'vehicles', vehicleId, {
      from: vehicle.verificationStatus,
      to: status,
      reason: reason ?? null,
    });
    return {
      id: updated.id,
      verification_status: updated.verificationStatus,
      is_public: status === VerificationStatus.APPROVED,
    };
  }

  /**
   * Decides a tariff. APPROVE atomically supersedes the previous live version
   * and activates the submitted one; the public price indicator changes in the
   * same transaction or not at all.
   */
  async decidePricing(admin: AuthenticatedUser, pricingId: string, action: DecisionAction, reason?: string) {
    const pricing = await this.prisma.vehiclePricing.findUnique({
      where: { id: pricingId },
    });
    if (!pricing) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Pricing version not found.');
    }

    if (action === 'APPROVE') {
      // Only PENDING_REVIEW rows can be approved: re-approving history or a
      // superseded version would silently rewind the live price.
      if (pricing.status !== 'PENDING_REVIEW') {
        throw new ConflictAppException(
          ErrorCode.CONFLICT,
          `This version is ${pricing.status}; only a PENDING_REVIEW submission can be approved.`,
        );
      }

      const updated = await this.prisma.$transaction(async (tx) => {
        await tx.vehiclePricing.updateMany({
          where: { vehicleId: pricing.vehicleId, status: 'APPROVED' },
          data: { status: 'SUPERSEDED', effectiveTo: new Date() },
        });
        return tx.vehiclePricing.update({
          where: { id: pricingId },
          data: {
            status: 'APPROVED',
            reviewedByUserId: admin.userId,
            reviewedAt: new Date(),
            decisionReason: reason ?? null,
            effectiveFrom: pricing.effectiveFrom ?? new Date(),
          },
        });
      });
      await this.audit(admin, 'PRICING_APPROVED', 'vehicle_pricing', pricingId, {
        vehicleId: pricing.vehicleId,
        version: pricing.version,
        superseded: true,
      });
      return {
        id: updated.id,
        version: updated.version,
        status: updated.status,
        vehicle_id: updated.vehicleId,
      };
    }

    // REJECT / REQUEST_CHANGES / SUSPEND
    const status =
      action === 'REJECT'
        ? 'REJECTED'
        : action === 'REQUEST_CHANGES'
          ? 'PENDING_REVIEW' // stays pending but now carries the admin's reason
          : 'SUPERSEDED';
    if (action === 'REQUEST_CHANGES' && !reason) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'decisionReason is required when requesting changes.',
      );
    }
    const updated = await this.prisma.vehiclePricing.update({
      where: { id: pricingId },
      data: {
        status,
        reviewedByUserId: admin.userId,
        reviewedAt: new Date(),
        decisionReason: reason ?? null,
      },
    });
    await this.audit(admin, 'PRICING_DECIDED', 'vehicle_pricing', pricingId, {
      from: pricing.status,
      to: status,
      reason: reason ?? null,
    });
    return {
      id: updated.id,
      version: updated.version,
      status: updated.status,
      vehicle_id: updated.vehicleId,
      decision_reason: updated.decisionReason,
    };
  }

  // ----------------------------------------------------------------- helpers

  private statusFor(action: DecisionAction, reason?: string): VerificationStatus {
    switch (action) {
      case 'APPROVE':
        return VerificationStatus.APPROVED;
      case 'REJECT':
        if (!reason) {
          throw new BadRequestAppException(
            ErrorCode.VALIDATION_FAILED,
            'decisionReason is required when rejecting.',
          );
        }
        return VerificationStatus.REJECTED;
      case 'REQUEST_CHANGES':
        if (!reason) {
          throw new BadRequestAppException(
            ErrorCode.VALIDATION_FAILED,
            'decisionReason is required when requesting changes.',
          );
        }
        return VerificationStatus.ACTION_REQUIRED;
      case 'SUSPEND':
        return VerificationStatus.SUSPENDED;
    }
  }

  private async audit(
    admin: AuthenticatedUser,
    action: string,
    entity: string,
    entityId: string,
    changes: Prisma.InputJsonValue,
  ) {
    await this.prisma.auditLog.create({
      data: {
        actorId: admin.userId,
        actorRole: admin.role,
        action,
        targetEntity: entity,
        targetId: entityId,
        changes,
      },
    });
  }

  private tariffView(p: {
    localIncludedKm: number | null;
    localAmountPaise: bigint | null;
    perKmPaise: bigint | null;
    hourlyPaise: bigint | null;
    fullDayPaise: bigint | null;
    overnightPaise: bigint | null;
    outstationPerDayPaise: bigint | null;
    outstationPerKmPaise: bigint | null;
  }) {
    return {
      local_included_km: p.localIncludedKm,
      local_amount_paise: p.localAmountPaise?.toString() ?? null,
      per_km_paise: p.perKmPaise?.toString() ?? null,
      hourly_paise: p.hourlyPaise?.toString() ?? null,
      full_day_paise: p.fullDayPaise?.toString() ?? null,
      overnight_paise: p.overnightPaise?.toString() ?? null,
      outstation_per_day_paise: p.outstationPerDayPaise?.toString() ?? null,
      outstation_per_km_paise: p.outstationPerKmPaise?.toString() ?? null,
    };
  }
}
