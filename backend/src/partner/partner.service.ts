import { Injectable } from '@nestjs/common';
import { VerificationStatus } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import {
  BadRequestAppException,
  ConflictAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import { Role } from '../auth/domain/roles';
import {
  AddPartnerDocumentDto,
  AddVehicleDocumentDto,
  AddVehicleDto,
  RegisterPartnerDto,
  UpdatePartnerProfileDto,
  UpdateVehicleDto,
} from './dto/partner.dto';

/**
 * Partner onboarding and fleet management.
 *
 * The invariants this service exists to protect:
 *   * a partner sees and edits ONLY its own fleet — a foreign id is reported as
 *     not-found rather than forbidden, so the API cannot be used to discover
 *     which vehicle ids exist;
 *   * a partner can never make its own vehicle bookable. Verification is an
 *     admin decision; every new or materially edited vehicle returns to
 *     PENDING_SUBMISSION and is invisible to the public catalog;
 *   * a partner cannot price a vehicle through this module (tariffs are a
 *     separate, reviewed resource);
 *   * a vehicle committed to an upcoming booking cannot be deleted out from
 *     under that booking.
 */
@Injectable()
export class PartnerService {
  constructor(private readonly prisma: PrismaService) {}

  // ------------------------------------------------------------ onboarding

  /**
   * Idempotent partner registration. Establishes the business profile (status
   * PENDING_SUBMISSION — never auto-approved) and upgrades the caller's role so
   * subsequent tokens carry the partner role.
   */
  async register(userId: string, dto: RegisterPartnerDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'User not found.');
    }

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.partnerProfile.findUnique({ where: { userId } });
      const profile = existing
        ? await tx.partnerProfile.update({
            where: { userId },
            data: {
              companyName: dto.companyName,
              contactName: dto.contactName ?? existing.contactName,
              baseCity: dto.baseCity,
              serviceCities: dto.serviceCities ?? existing.serviceCities,
              languagesSpoken: dto.languagesSpoken ?? existing.languagesSpoken,
              experienceYears: dto.experienceYears ?? existing.experienceYears,
              licenseNumber: dto.licenseNumber ?? existing.licenseNumber,
              emergencyContactName:
                dto.emergencyContactName ?? existing.emergencyContactName,
              emergencyContactPhone:
                dto.emergencyContactPhone ?? existing.emergencyContactPhone,
              tradeLicenseNumber:
                dto.tradeLicenseNumber ?? existing.tradeLicenseNumber,
              panNumber: dto.panNumber ?? existing.panNumber,
              gstin: dto.gstin ?? existing.gstin,
            },
          })
        : await tx.partnerProfile.create({
            data: {
              userId,
              companyName: dto.companyName,
              contactName: dto.contactName,
              baseCity: dto.baseCity,
              serviceCities: dto.serviceCities ?? [],
              languagesSpoken: dto.languagesSpoken ?? ['Hindi'],
              experienceYears: dto.experienceYears ?? 0,
              licenseNumber: dto.licenseNumber,
              emergencyContactName: dto.emergencyContactName,
              emergencyContactPhone: dto.emergencyContactPhone,
              tradeLicenseNumber: dto.tradeLicenseNumber,
              panNumber: dto.panNumber,
              gstin: dto.gstin,
            },
          });

      // Partner endpoints accept driver OR fleetOwner; promoting the role keeps
      // the client's navigation and future tokens consistent.
      if (user.primaryRole === Role.Driver || user.primaryRole === Role.Customer) {
        await tx.user.update({
          where: { id: userId },
          data: { primaryRole: Role.FleetOwner },
        });
      }

      return this.viewProfile(profile);
    });
  }

  async getProfile(userId: string) {
    const partner = await this.requirePartner(userId);
    const [vehicleCount, documentCount] = await Promise.all([
      this.prisma.vehicle.count({ where: { fleetOwnerId: partner.id } }),
      this.prisma.partnerDocument.count({ where: { partnerId: partner.id } }),
    ]);
    return {
      ...this.viewProfile(partner),
      vehicle_count: vehicleCount,
      document_count: documentCount,
    };
  }

  /**
   * Professional/legal detail edits. Editing an APPROVED partner returns the
   * profile to review, because the reviewed facts no longer match what was
   * approved. A SUSPENDED partner cannot edit its way out of suspension.
   */
  async updateProfile(userId: string, dto: UpdatePartnerProfileDto) {
    const partner = await this.requirePartner(userId);
    if (partner.verificationStatus === VerificationStatus.SUSPENDED) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This partner account is suspended. Contact ShadiDriver operations.',
      );
    }

    const updated = await this.prisma.partnerProfile.update({
      where: { userId },
      data: {
        ...(dto.companyName !== undefined ? { companyName: dto.companyName } : {}),
        ...(dto.contactName !== undefined ? { contactName: dto.contactName } : {}),
        ...(dto.baseCity !== undefined ? { baseCity: dto.baseCity } : {}),
        ...(dto.serviceCities !== undefined
          ? { serviceCities: dto.serviceCities }
          : {}),
        ...(dto.languagesSpoken !== undefined
          ? { languagesSpoken: dto.languagesSpoken }
          : {}),
        ...(dto.experienceYears !== undefined
          ? { experienceYears: dto.experienceYears }
          : {}),
        ...(dto.licenseNumber !== undefined
          ? { licenseNumber: dto.licenseNumber }
          : {}),
        ...(dto.emergencyContactName !== undefined
          ? { emergencyContactName: dto.emergencyContactName }
          : {}),
        ...(dto.emergencyContactPhone !== undefined
          ? { emergencyContactPhone: dto.emergencyContactPhone }
          : {}),
        ...(dto.tradeLicenseNumber !== undefined
          ? { tradeLicenseNumber: dto.tradeLicenseNumber }
          : {}),
        ...(dto.panNumber !== undefined ? { panNumber: dto.panNumber } : {}),
        ...(dto.gstin !== undefined ? { gstin: dto.gstin } : {}),
        ...(partner.verificationStatus === VerificationStatus.APPROVED
          ? {
              verificationStatus: VerificationStatus.UNDER_REVIEW,
              reviewedAt: null,
              decisionReason: null,
            }
          : {}),
      },
    });
    return this.viewProfile(updated);
  }

  /** Submits the partner (and its fleet) for admin verification. */
  async submitForReview(userId: string) {
    const partner = await this.requirePartner(userId);
    if (partner.verificationStatus === VerificationStatus.SUSPENDED) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This partner account is suspended.',
      );
    }
    const vehicleCount = await this.prisma.vehicle.count({
      where: { fleetOwnerId: partner.id, isActive: true },
    });
    if (vehicleCount === 0) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Add at least one vehicle before submitting for verification.',
      );
    }

    const updated = await this.prisma.partnerProfile.update({
      where: { userId },
      data: {
        verificationStatus: VerificationStatus.SUBMITTED,
        submittedAt: new Date(),
        decisionReason: null,
      },
    });
    return this.viewProfile(updated);
  }

  // ------------------------------------------------------------------ fleet

  async listVehicles(userId: string) {
    const partner = await this.requirePartner(userId);
    const vehicles = await this.prisma.vehicle.findMany({
      where: { fleetOwnerId: partner.id },
      include: {
        vehicleType: true,
        documents: {
          select: {
            documentType: true,
            verificationStatus: true,
            expiryDate: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return { items: vehicles.map((v) => this.viewVehicle(v)), total: vehicles.length };
  }

  async addVehicle(userId: string, dto: AddVehicleDto) {
    const partner = await this.requirePartner(userId);
    const vehicleType = await this.prisma.vehicleType.findUnique({
      where: { id: dto.vehicleTypeId },
    });
    if (!vehicleType || !vehicleType.isActive) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Unknown or inactive vehicle type.',
      );
    }

    const registrationNumber = dto.registrationNumber.replace(/[ -]/g, '').toUpperCase();
    const clash = await this.prisma.vehicle.findUnique({
      where: { registrationNumber },
      select: { id: true },
    });
    if (clash) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'A vehicle with this registration number is already registered.',
      );
    }

    const vehicle = await this.prisma.vehicle.create({
      data: {
        // Server-generated: partners never choose fleet references.
        fleetCode: await this.nextFleetCode(partner.baseCity ?? dto.city),
        vehicleTypeId: dto.vehicleTypeId,
        fleetOwnerId: partner.id,
        yearOfManufacture: dto.yearOfManufacture,
        registrationNumber,
        color: dto.color,
        fuelType: dto.fuelType,
        transmission: dto.transmission,
        city: dto.city,
        serviceAreas: dto.serviceAreas ?? [],
        amenityTags: dto.amenities ?? [],
        photoUrls: dto.photoUrls ?? [],
        // A new vehicle is NOT bookable: verification is an admin decision.
        verificationStatus: VerificationStatus.PENDING_SUBMISSION,
        isActive: true,
        isAvailable: true,
      },
      include: { vehicleType: true },
    });
    return this.viewVehicle(vehicle);
  }

  async updateVehicle(userId: string, vehicleId: string, dto: UpdateVehicleDto) {
    const vehicle = await this.requireOwnVehicle(userId, vehicleId);

    // Materially editing an approved vehicle invalidates the review that
    // approved it, so it goes back into the verification queue and out of the
    // public catalog until it is re-approved.
    const requiresReview =
      vehicle.verificationStatus === VerificationStatus.APPROVED;

    const updated = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: {
        ...(dto.yearOfManufacture !== undefined
          ? { yearOfManufacture: dto.yearOfManufacture }
          : {}),
        ...(dto.color !== undefined ? { color: dto.color } : {}),
        ...(dto.fuelType !== undefined ? { fuelType: dto.fuelType } : {}),
        ...(dto.transmission !== undefined ? { transmission: dto.transmission } : {}),
        ...(dto.city !== undefined ? { city: dto.city } : {}),
        ...(dto.serviceAreas !== undefined ? { serviceAreas: dto.serviceAreas } : {}),
        ...(dto.amenities !== undefined ? { amenityTags: dto.amenities } : {}),
        ...(dto.photoUrls !== undefined ? { photoUrls: dto.photoUrls } : {}),
        ...(requiresReview
          ? { verificationStatus: VerificationStatus.PENDING_SUBMISSION }
          : {}),
      },
      include: { vehicleType: true },
    });
    return this.viewVehicle(updated);
  }

  /**
   * Soft-removes a vehicle from the bookable fleet. Refused while the vehicle
   * is committed to an upcoming booking, so a partner edit can never silently
   * break a confirmed customer reservation.
   */
  async removeVehicle(userId: string, vehicleId: string) {
    await this.requireOwnVehicle(userId, vehicleId);

    const upcoming = await this.prisma.availability.findFirst({
      where: {
        vehicleId,
        status: 'BOOKED',
        endTime: { gt: new Date() },
      },
      select: { id: true },
    });
    if (upcoming) {
      throw new ConflictAppException(
        ErrorCode.CONFLICT,
        'This vehicle is committed to an upcoming booking and cannot be removed. Contact operations.',
      );
    }

    const updated = await this.prisma.vehicle.update({
      where: { id: vehicleId },
      data: { isActive: false, isAvailable: false },
      include: { vehicleType: true },
    });
    return this.viewVehicle(updated);
  }

  // -------------------------------------------------------------- documents

  async addVehicleDocument(
    userId: string,
    vehicleId: string,
    dto: AddVehicleDocumentDto,
  ) {
    await this.requireOwnVehicle(userId, vehicleId);
    const document = await this.prisma.vehicleDocument.upsert({
      where: {
        vehicleId_documentType: {
          vehicleId,
          documentType: dto.documentType as never,
        },
      },
      create: {
        vehicleId,
        documentType: dto.documentType as never,
        documentNumber: dto.documentNumber,
        storagePath: dto.storagePath,
        mimeType: dto.mimeType,
        issuedDate: dto.issuedDate ? new Date(dto.issuedDate) : null,
        expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        // Re-uploaded paperwork is unreviewed again, even if the previous
        // version had been verified.
        verificationStatus: 'PENDING_REVIEW',
        rejectionReason: null,
      },
      update: {
        documentNumber: dto.documentNumber,
        storagePath: dto.storagePath,
        mimeType: dto.mimeType,
        issuedDate: dto.issuedDate ? new Date(dto.issuedDate) : null,
        expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        verificationStatus: 'PENDING_REVIEW',
        rejectionReason: null,
        verifiedBy: null,
        verifiedAt: null,
      },
    });
    return {
      id: document.id,
      vehicle_id: vehicleId,
      document_type: document.documentType,
      verification_status: document.verificationStatus,
      expires_at: document.expiryDate,
    };
  }

  async addPartnerDocument(userId: string, dto: AddPartnerDocumentDto) {
    const partner = await this.requirePartner(userId);
    const document = await this.prisma.partnerDocument.upsert({
      where: {
        partnerId_documentType: {
          partnerId: partner.id,
          documentType: dto.documentType as never,
        },
      },
      create: {
        partnerId: partner.id,
        documentType: dto.documentType as never,
        documentNumber: dto.documentNumber,
        storagePath: dto.storagePath,
        mimeType: dto.mimeType,
        issuedDate: dto.issuedDate ? new Date(dto.issuedDate) : null,
        expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
      },
      update: {
        documentNumber: dto.documentNumber,
        storagePath: dto.storagePath,
        mimeType: dto.mimeType,
        issuedDate: dto.issuedDate ? new Date(dto.issuedDate) : null,
        expiryDate: dto.expiryDate ? new Date(dto.expiryDate) : null,
        verificationStatus: 'PENDING_REVIEW',
        rejectionReason: null,
        verifiedBy: null,
        verifiedAt: null,
      },
    });
    return {
      id: document.id,
      document_type: document.documentType,
      verification_status: document.verificationStatus,
      expires_at: document.expiryDate,
    };
  }

  // ----------------------------------------------------------------- helpers

  private async requirePartner(userId: string) {
    const partner = await this.prisma.partnerProfile.findUnique({
      where: { userId },
    });
    if (!partner) {
      throw new NotFoundAppException(
        ErrorCode.NOT_FOUND,
        'No partner profile for this account. Register as a partner first.',
      );
    }
    return partner;
  }

  /**
   * Ownership gate. A vehicle belonging to another partner is reported as
   * NOT_FOUND — never FORBIDDEN — so a partner cannot enumerate the fleet of
   * anyone else by probing ids.
   */
  private async requireOwnVehicle(userId: string, vehicleId: string) {
    const partner = await this.requirePartner(userId);
    const vehicle = await this.prisma.vehicle.findUnique({ where: { id: vehicleId } });
    if (!vehicle || vehicle.fleetOwnerId !== partner.id) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }
    return vehicle;
  }

  private async nextFleetCode(city: string): Promise<string> {
    const cityCode = city.replace(/[^A-Za-z]/g, '').slice(0, 3).toUpperCase() || 'IND';
    // Collision-free within a city by counting existing codes with the prefix.
    const existing = await this.prisma.vehicle.count({
      where: { fleetCode: { startsWith: `SD-${cityCode}-` } },
    });
    for (let i = 1; i <= 20; i++) {
      const candidate = `SD-${cityCode}-${String(existing + i).padStart(5, '0')}`;
      const taken = await this.prisma.vehicle.findUnique({
        where: { fleetCode: candidate },
        select: { id: true },
      });
      if (!taken) return candidate;
    }
    throw new ConflictAppException(
      ErrorCode.CONFLICT,
      'Could not allocate a fleet reference. Please retry.',
    );
  }

  private viewProfile(partner: {
    id: string;
    companyName: string;
    contactName: string | null;
    baseCity: string | null;
    serviceCities: string[];
    languagesSpoken: string[];
    experienceYears: number;
    verificationStatus: VerificationStatus;
    submittedAt: Date | null;
    reviewedAt: Date | null;
    decisionReason: string | null;
  }) {
    return {
      id: partner.id,
      company_name: partner.companyName,
      contact_name: partner.contactName,
      base_city: partner.baseCity,
      service_cities: partner.serviceCities,
      languages_spoken: partner.languagesSpoken,
      experience_years: partner.experienceYears,
      verification_status: partner.verificationStatus,
      submitted_at: partner.submittedAt,
      reviewed_at: partner.reviewedAt,
      decision_reason: partner.decisionReason,
      // A verified partner is not a verified fleet; the client must not assume.
      is_verified: partner.verificationStatus === VerificationStatus.APPROVED,
      can_receive_bookings: partner.verificationStatus === VerificationStatus.APPROVED,
    };
  }

  private viewVehicle(vehicle: {
    id: string;
    fleetCode: string;
    vehicleTypeId: string;
    yearOfManufacture: number;
    registrationNumber: string;
    color: string;
    fuelType: string;
    transmission: string;
    city: string;
    serviceAreas: string[];
    amenityTags: string[];
    photoUrls: string[];
    verificationStatus: VerificationStatus;
    isActive: boolean;
    isAvailable: boolean;
    vehicleType?: { displayName: string; seatingCap: number; vehicleClass: string };
    documents?: {
      documentType: string;
      verificationStatus: string;
      expiryDate: Date | null;
    }[];
  }) {
    return {
      id: vehicle.id,
      fleet_code: vehicle.fleetCode,
      vehicle_type_id: vehicle.vehicleTypeId,
      display_name: vehicle.vehicleType?.displayName ?? null,
      seating_capacity: vehicle.vehicleType?.seatingCap ?? null,
      vehicle_class: vehicle.vehicleType?.vehicleClass ?? null,
      year: vehicle.yearOfManufacture,
      // The partner owns this vehicle, so its own plate is legitimately visible.
      registration_number: vehicle.registrationNumber,
      color: vehicle.color,
      fuel_type: vehicle.fuelType,
      transmission: vehicle.transmission,
      city: vehicle.city,
      service_areas: vehicle.serviceAreas,
      amenities: vehicle.amenityTags,
      photo_urls: vehicle.photoUrls,
      verification_status: vehicle.verificationStatus,
      is_active: vehicle.isActive,
      is_available: vehicle.isAvailable,
      // Only APPROVED + active vehicles reach customers. Telling the partner
      // this directly stops them believing a pending car is already earning.
      is_bookable: vehicle.isActive && vehicle.isAvailable &&
        vehicle.verificationStatus === VerificationStatus.APPROVED,
      documents: (vehicle.documents ?? []).map((d) => ({
        type: d.documentType,
        status: d.verificationStatus,
        expires_at: d.expiryDate,
      })),
    };
  }
}
