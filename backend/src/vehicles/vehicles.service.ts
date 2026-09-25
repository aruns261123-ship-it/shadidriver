import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { BadRequestAppException, NotFoundAppException } from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';
import {
  ApprovedTariff,
  PublicVehicleDetail,
  PublicVehicleListItem,
  PublicVehicleSource,
  toPublicVehicleDetail,
  toPublicVehicleListItem,
} from './dto/public-vehicle.dto';

export interface VehicleSearchInput {
  city?: string;
  vehicleTypeIds?: string[];
  vehicleClass?: string;
  minSeatingCapacity?: number;
  page: number;
  limit: number;
}

/** Verified, publishable reviews only — moderation state gates the aggregate. */
const PUBLISHED_REVIEWS = { where: { status: 'PUBLISHED' as const } };

/**
 * The single relation projection every public/customer vehicle payload is built
 * from. Chauffeur and partner relations are selected ONLY for a boolean
 * verification check — never for their identity fields.
 */
const PUBLIC_VEHICLE_INCLUDE = {
  vehicleType: true,
  independentDriver: { select: { verificationStatus: true } },
  fleetOwner: {
    select: {
      drivers: {
        where: { verificationStatus: 'APPROVED' as const },
        select: { id: true },
        take: 1,
      },
    },
  },
  reviews: { ...PUBLISHED_REVIEWS, select: { overallRating: true } },
  // The tariff actually in force. Reviewed-and-APPROVED only: a partner's
  // pending submission is not a customer-visible price, and the legacy
  // base_price_paise column (default 0) is no longer published at all.
  pricingVersions: {
    where: { status: 'APPROVED' as const },
    orderBy: { version: 'desc' as const },
    take: 1,
    select: {
      localIncludedKm: true,
      localAmountPaise: true,
      perKmPaise: true,
      hourlyPaise: true,
      fullDayPaise: true,
      overnightPaise: true,
      outstationPerDayPaise: true,
      outstationPerKmPaise: true,
    },
  },
} as const;

/** Eligibility rule for anything that reaches a customer. */
const PUBLICLY_LISTABLE = {
  verificationStatus: 'APPROVED' as const,
  isActive: true,
} as const;

/**
 * Real vehicle catalog backed by the database. Only VERIFIED + ACTIVE +
 * available vehicles are surfaced to customers; unverified or suspended
 * fleets are excluded from the public catalog (booking eligibility).
 *
 * Every response is produced by the public DTO layer, so chauffeur and partner
 * identity can never reach a customer-facing payload even if this service
 * starts selecting more relations.
 */
@Injectable()
export class VehiclesService {
  constructor(private readonly prisma: PrismaService) {}

  async searchVehicles(input: VehicleSearchInput): Promise<{
    items: PublicVehicleListItem[];
    meta: { page: number; limit: number; total_records: number; has_more: boolean };
  }> {
    const where: Prisma.VehicleWhereInput = {
      verificationStatus: 'APPROVED',
      isActive: true,
      isAvailable: true,
      ...(input.city ? { city: { contains: input.city, mode: 'insensitive' } } : {}),
      ...(input.vehicleTypeIds && input.vehicleTypeIds.length > 0
        ? { vehicleTypeId: { in: input.vehicleTypeIds } }
        : {}),
      ...(input.vehicleClass || input.minSeatingCapacity
        ? {
            vehicleType: {
              ...(input.vehicleClass ? { vehicleClass: input.vehicleClass } : {}),
              ...(input.minSeatingCapacity
                ? { seatingCap: { gte: input.minSeatingCapacity } }
                : {}),
            },
          }
        : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.vehicle.findMany({
        where,
        include: PUBLIC_VEHICLE_INCLUDE,
        orderBy: [{ city: 'asc' }, { basePricePaise: 'asc' }],
        skip: (input.page - 1) * input.limit,
        take: input.limit,
      }),
      this.prisma.vehicle.count({ where }),
    ]);

    const items = rows.map((v) =>
      toPublicVehicleListItem(this.toSource(v, v.reviews)),
    );

    return {
      items,
      meta: {
        page: input.page,
        limit: input.limit,
        total_records: total,
        has_more: input.page * input.limit < total,
      },
    };
  }

  async getVehicleById(id: string): Promise<PublicVehicleDetail> {
    if (!/^[0-9a-fA-F-]{36}$/.test(id)) {
      throw new BadRequestAppException(ErrorCode.VALIDATION_FAILED, 'Invalid vehicle id.');
    }
    const v = await this.prisma.vehicle.findUnique({
      where: { id },
      include: {
        ...PUBLIC_VEHICLE_INCLUDE,
        documents: { select: { verificationStatus: true, expiryDate: true } },
      },
    });
    // The public detail endpoint mirrors the catalog's eligibility rule: a
    // vehicle that cannot be listed cannot be fetched by guessing its id.
    if (!v || !v.isActive || v.verificationStatus !== 'APPROVED') {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }

    const now = Date.now();
    const soon = now + 1000 * 60 * 60 * 24 * 60;
    const documents = v.documents ?? [];

    return toPublicVehicleDetail(
      this.toSource(v, v.reviews, {
        total: documents.length,
        verified: documents.filter((d) => d.verificationStatus === 'VERIFIED').length,
        expiringSoon: documents.filter(
          (d) => d.expiryDate !== null && d.expiryDate.getTime() <= soon,
        ).length,
      }),
    );
  }

  /**
   * Projects specific vehicles through the SAME public DTO as the catalog, so a
   * caller (e.g. favourites) cannot accidentally return a richer payload.
   * Only publicly listable vehicles are returned — an unlisted vehicle is
   * invisible here, which also stops this endpoint being used as an existence
   * oracle for unpublished fleet.
   */
  async getPublicListItemsByIds(ids: string[]): Promise<PublicVehicleListItem[]> {
    if (ids.length === 0) return [];
    const rows = await this.prisma.vehicle.findMany({
      where: { id: { in: ids }, ...PUBLICLY_LISTABLE },
      include: PUBLIC_VEHICLE_INCLUDE,
    });
    const byId = new Map(
      rows.map((v) => [v.id, toPublicVehicleListItem(this.toSource(v, v.reviews))]),
    );
    // Preserve the caller's ordering (e.g. most-recently-favourited first).
    return ids.map((id) => byId.get(id)).filter((v): v is PublicVehicleListItem => !!v);
  }

  /** TRUE when the vehicle exists and is publicly listable. */
  async isPubliclyListable(vehicleId: string): Promise<boolean> {
    const found = await this.prisma.vehicle.findFirst({
      where: { id: vehicleId, ...PUBLICLY_LISTABLE },
      select: { id: true },
    });
    return found !== null;
  }

  async getVehicleTypes() {
    const types = await this.prisma.vehicleType.findMany({
      where: { isActive: true },
      orderBy: [{ vehicleClass: 'asc' }, { displayName: 'asc' }],
    });
    return types.map((t) => ({
      id: t.id,
      make: t.make,
      model: t.model,
      display_name: t.displayName,
      seating_capacity: t.seatingCap,
      vehicle_class: t.vehicleClass,
      image_url: t.imageUrl,
      amenities: t.amenityTags,
    }));
  }

  /** Counts of verified+active+available vehicles per type (fleet picker). */
  async getAvailabilityByType(city?: string) {
    const grouped = await this.prisma.vehicle.groupBy({
      by: ['vehicleTypeId'],
      where: {
        verificationStatus: 'APPROVED',
        isActive: true,
        isAvailable: true,
        ...(city ? { city: { contains: city, mode: 'insensitive' } } : {}),
      },
      _count: { id: true },
    });
    return grouped.map((g) => ({ vehicle_type_id: g.vehicleTypeId, available: g._count.id }));
  }

  /**
   * Projects a vehicle row onto the DTO input. Identity-bearing relations
   * (`independentDriver`, `fleetOwner`) are reduced to a single boolean here,
   * so their contents never travel further into the response path.
   */
  private toSource(
    v: {
      id: string;
      fleetCode: string;
      vehicleTypeId: string;
      yearOfManufacture: number;
      color: string;
      fuelType: string;
      airConditioningType: string;
      isVintage: boolean;
      city: string;
      imageUrl: string | null;
      photoUrls: string[];
      amenityTags: string[];
      serviceAreas: string[];
      verificationStatus: string;
      isAvailable: boolean;
      pricingVersions: ApprovedTariff[];
      vehicleType: {
        id: string;
        displayName: string;
        make: string;
        model: string;
        seatingCap: number;
        vehicleClass: string;
        imageUrl: string | null;
        amenityTags: string[];
      };
      independentDriver: { verificationStatus: string } | null;
      fleetOwner: { drivers: { id: string }[] } | null;
    },
    reviews: { overallRating: number }[],
    documentCounts?: { total: number; verified: number; expiringSoon: number },
  ): PublicVehicleSource {
    const hasVerifiedChauffeur =
      v.independentDriver?.verificationStatus === 'APPROVED' ||
      (v.fleetOwner?.drivers.length ?? 0) > 0;

    const rating =
      reviews.length > 0
        ? Math.round((reviews.reduce((s, r) => s + r.overallRating, 0) / reviews.length) * 100) / 100
        : null;

    return {
      id: v.id,
      fleetCode: v.fleetCode,
      vehicleTypeId: v.vehicleTypeId,
      yearOfManufacture: v.yearOfManufacture,
      color: v.color,
      fuelType: v.fuelType,
      airConditioningType: v.airConditioningType,
      isVintage: v.isVintage,
      city: v.city,
      imageUrl: v.imageUrl,
      photoUrls: v.photoUrls,
      amenityTags: v.amenityTags,
      serviceAreas: v.serviceAreas,
      verificationStatus: v.verificationStatus,
      isAvailable: v.isAvailable,
      approvedTariff: v.pricingVersions?.[0] ?? null,
      vehicleType: v.vehicleType,
      hasVerifiedChauffeur,
      rating,
      reviewCount: reviews.length,
      documentCounts,
    };
  }
}
