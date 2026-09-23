import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../database/prisma.service';
import { BadRequestAppException, NotFoundAppException } from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

export interface VehicleSearchInput {
  city?: string;
  vehicleTypeIds?: string[];
  vehicleClass?: string;
  minSeatingCapacity?: number;
  page: number;
  limit: number;
}

export interface VehicleListItem {
  id: string;
  fleet_code: string;
  make: string;
  model: string;
  display_name: string;
  year: number;
  vehicle_class: string;
  seating_capacity: number;
  city: string;
  image_url: string | null;
  base_price_paise: string;
  amenities: string[];
  verification_status: string;
  is_available: boolean;
  average_rating: number | null;
  chauffeur_name: string | null;
  chauffeur_id: string | null;
}

/**
 * Real vehicle catalog backed by the database. Only VERIFIED + ACTIVE +
 * available vehicles are surfaced to customers; unverified or suspended
 * fleets are excluded from the public catalog (booking eligibility).
 */
@Injectable()
export class VehiclesService {
  constructor(private readonly prisma: PrismaService) {}

  async searchVehicles(input: VehicleSearchInput): Promise<{
    items: VehicleListItem[];
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
        include: {
          vehicleType: true,
          independentDriver: { include: { user: true } },
          reviews: { select: { overallRating: true } },
        },
        orderBy: [{ city: 'asc' }, { basePricePaise: 'asc' }],
        skip: (input.page - 1) * input.limit,
        take: input.limit,
      }),
      this.prisma.vehicle.count({ where }),
    ]);

    const items = rows.map((v) => {
      const rating =
        v.reviews.length > 0
          ? v.reviews.reduce((sum, r) => sum + r.overallRating, 0) / v.reviews.length
          : null;
      return {
        id: v.id,
        fleet_code: v.fleetCode,
        make: v.vehicleType.make,
        model: v.vehicleType.model,
        display_name: v.vehicleType.displayName,
        year: v.yearOfManufacture,
        vehicle_class: v.vehicleType.vehicleClass,
        seating_capacity: v.vehicleType.seatingCap,
        city: v.city,
        image_url: v.imageUrl ?? v.vehicleType.imageUrl ?? null,
        base_price_paise: v.basePricePaise.toString(),
        amenities: [...v.vehicleType.amenityTags, ...v.amenityTags],
        verification_status: v.verificationStatus,
        is_available: v.isAvailable,
        average_rating: rating !== null ? Math.round(rating * 100) / 100 : null,
        chauffeur_name: v.independentDriver?.user.fullName ?? null,
        chauffeur_id: v.independentDriver?.userId ?? null,
      };
    });

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

  async getVehicleById(id: string) {
    if (!/^[0-9a-fA-F-]{36}$/.test(id)) {
      throw new BadRequestAppException(ErrorCode.VALIDATION_FAILED, 'Invalid vehicle id.');
    }
    const v = await this.prisma.vehicle.findUnique({
      where: { id },
      include: {
        vehicleType: true,
        independentDriver: {
          include: {
            user: true,
            reviews: { select: { overallRating: true } },
          },
        },
        fleetOwner: true,
        documents: {
          select: { documentType: true, verificationStatus: true, expiryDate: true },
        },
      },
    });
    if (!v || !v.isActive) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }

    const driverRating =
      v.independentDriver && v.independentDriver.reviews.length > 0
        ? v.independentDriver.reviews.reduce((s, r) => s + r.overallRating, 0) /
          v.independentDriver.reviews.length
        : null;

    return {
      id: v.id,
      fleet_code: v.fleetCode,
      make: v.vehicleType.make,
      model: v.vehicleType.model,
      display_name: v.vehicleType.displayName,
      year: v.yearOfManufacture,
      color: v.color,
      vehicle_class: v.vehicleType.vehicleClass,
      seating_capacity: v.vehicleType.seatingCap,
      fuel_type: v.fuelType,
      air_conditioning: v.airConditioningType,
      is_vintage: v.isVintage,
      city: v.city,
      service_areas: v.serviceAreas,
      amenities: [...v.vehicleType.amenityTags, ...v.amenityTags],
      photos: v.photoUrls,
      image_url: v.imageUrl ?? v.vehicleType.imageUrl ?? null,
      base_price_paise: v.basePricePaise.toString(),
      verification_status: v.verificationStatus,
      is_available: v.isAvailable,
      owner: v.fleetOwner ? { id: v.fleetOwner.id, company_name: v.fleetOwner.companyName } : null,
      chauffeur: v.independentDriver
        ? {
            id: v.independentDriver.userId,
            full_name: v.independentDriver.user.fullName,
            avatar_url: v.independentDriver.user.avatarUrl,
            experience_years: v.independentDriver.experienceYears,
            languages_spoken: v.independentDriver.languagesSpoken,
            bio: v.independentDriver.bio,
            verification_status: v.independentDriver.verificationStatus,
            duty_status: v.independentDriver.dutyStatus,
            average_rating: driverRating !== null ? Math.round(driverRating * 100) / 100 : null,
            total_trips_completed: v.independentDriver.totalTripsCompleted,
          }
        : null,
      documents: v.documents.map((d) => ({
        type: d.documentType,
        status: d.verificationStatus,
        expires_at: d.expiryDate,
      })),
    };
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
}
