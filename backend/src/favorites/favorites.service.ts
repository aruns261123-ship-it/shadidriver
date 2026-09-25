import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import { VehiclesService } from '../vehicles/vehicles.service';
import { PublicVehicleListItem } from '../vehicles/dto/public-vehicle.dto';
import {
  BadRequestAppException,
  NotFoundAppException,
} from '../auth/errors/auth.exceptions';
import { ErrorCode } from '../common/errors/error-codes';

const UUID_PATTERN = /^[0-9a-fA-F-]{36}$/;

/** A saved-vehicle list is a convenience, not a data store. */
export const MAX_FAVORITES = 100;

export interface FavoritesView {
  items: PublicVehicleListItem[];
  vehicle_ids: string[];
  total: number;
  /** Saved vehicles that are no longer publicly bookable. */
  unavailable_count: number;
}

/**
 * Persistent, per-account vehicle favourites.
 *
 * The list is built entirely from the PUBLIC vehicle projection, so a customer
 * can never use favourites to read chauffeur or partner identity. Unlisted
 * vehicles are silently absent rather than exposed, which also means this
 * module cannot be used to probe for unpublished fleet.
 */
@Injectable()
export class FavoritesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly vehicles: VehiclesService,
  ) {}

  async list(userId: string): Promise<FavoritesView> {
    const rows = await this.prisma.favoriteVehicle.findMany({
      where: { customerFk: userId },
      orderBy: { createdAt: 'desc' },
      select: { vehicleId: true },
    });
    const ids = rows.map((r) => r.vehicleId);
    const items = await this.vehicles.getPublicListItemsByIds(ids);

    return {
      items,
      vehicle_ids: items.map((v) => v.id),
      total: ids.length,
      unavailable_count: ids.length - items.length,
    };
  }

  /**
   * Idempotent save. Re-saving a favourited vehicle is a no-op, so a double tap
   * or a retried request cannot fail or duplicate.
   */
  async add(userId: string, vehicleId: string): Promise<FavoritesView> {
    this.assertVehicleId(vehicleId);
    if (!(await this.vehicles.isPubliclyListable(vehicleId))) {
      throw new NotFoundAppException(ErrorCode.NOT_FOUND, 'Vehicle not found.');
    }

    const existing = await this.prisma.favoriteVehicle.count({
      where: { customerFk: userId },
    });
    const alreadySaved = await this.prisma.favoriteVehicle.findUnique({
      where: { customerFk_vehicleId: { customerFk: userId, vehicleId } },
      select: { id: true },
    });
    if (!alreadySaved && existing >= MAX_FAVORITES) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        `You can save up to ${MAX_FAVORITES} vehicles. Remove one to add another.`,
      );
    }

    await this.prisma.favoriteVehicle.upsert({
      where: { customerFk_vehicleId: { customerFk: userId, vehicleId } },
      create: { customerFk: userId, vehicleId },
      update: {},
    });
    return this.list(userId);
  }

  /** Idempotent remove — deleting something already gone is a success. */
  async remove(userId: string, vehicleId: string): Promise<FavoritesView> {
    this.assertVehicleId(vehicleId);
    await this.prisma.favoriteVehicle.deleteMany({
      where: { customerFk: userId, vehicleId },
    });
    return this.list(userId);
  }

  /**
   * Merges a signed-out visitor's local shortlist into the account.
   *
   * A guest shortlist can go stale between browsing and signing in, so
   * unlisted/unknown ids are skipped rather than failing the whole sign-in —
   * and the skipped ids are reported so the client can reconcile. Bounded by
   * [MAX_FAVORITES] so a tampered payload cannot write unbounded rows.
   */
  async merge(userId: string, vehicleIds: string[]): Promise<
    FavoritesView & { ignored_vehicle_ids: string[] }
  > {
    const requested = [...new Set(vehicleIds)].filter((id) => UUID_PATTERN.test(id));
    const ignored = [...new Set(vehicleIds)].filter((id) => !UUID_PATTERN.test(id));

    const listable = await this.vehicles.getPublicListItemsByIds(requested);
    const listableIds = new Set(listable.map((v) => v.id));
    for (const id of requested) {
      if (!listableIds.has(id)) ignored.push(id);
    }

    const current = await this.prisma.favoriteVehicle.findMany({
      where: { customerFk: userId },
      select: { vehicleId: true },
    });
    const currentIds = new Set(current.map((r) => r.vehicleId));
    const room = Math.max(0, MAX_FAVORITES - currentIds.size);
    const toCreate = listable
      .filter((v) => !currentIds.has(v.id))
      .slice(0, room)
      .map((v) => ({ customerFk: userId, vehicleId: v.id }));

    if (toCreate.length > 0) {
      await this.prisma.favoriteVehicle.createMany({
        data: toCreate,
        skipDuplicates: true,
      });
    }

    return { ...(await this.list(userId)), ignored_vehicle_ids: ignored };
  }

  private assertVehicleId(vehicleId: string): void {
    if (!UUID_PATTERN.test(vehicleId)) {
      throw new BadRequestAppException(
        ErrorCode.VALIDATION_FAILED,
        'Invalid vehicle id.',
      );
    }
  }
}
