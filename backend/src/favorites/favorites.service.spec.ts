import { FavoritesService, MAX_FAVORITES } from './favorites.service';
import { PublicVehicleListItem } from '../vehicles/dto/public-vehicle.dto';

const CUSTOMER = 'cust-1';
const V1 = '11111111-1111-4111-8111-111111111111';
const V2 = '22222222-2222-4222-8222-222222222222';
const V3 = '33333333-3333-4333-8333-333333333333';

function publicItem(id: string): PublicVehicleListItem {
  return {
    id,
    vehicle_type_id: 'VT_THAR',
    fleet_code: 'SD-VH-0001',
    make: 'Mahindra',
    model: 'Thar',
    display_name: 'Mahindra Thar',
    year: 2023,
    vehicle_class: 'PREMIUM_SUV',
    seating_capacity: 5,
    city: 'Delhi NCR',
    image_url: null,
    amenities: ['AC'],
    verification_status: 'APPROVED',
    is_available: true,
    has_verified_chauffeur: true,
    rating: null,
    review_count: 0,
    price_indicator_paise: '300000',
  };
}

describe('FavoritesService', () => {
  let service: FavoritesService;
  let prisma: any;
  /** ids the (stubbed) vehicles service considers publicly listable. */
  let listable: Set<string>;
  let rows: { customerFk: string; vehicleId: string; createdAt: Date }[];

  function build() {
    rows = [];
    listable = new Set([V1, V2, V3]);
    prisma = {
      favoriteVehicle: {
        findMany: jest.fn(async ({ where, orderBy, select }) => {
          void orderBy;
          void select;
          return rows.filter((r) => r.customerFk === where.customerFk);
        }),
        count: jest.fn(
          async ({ where }) => rows.filter((r) => r.customerFk === where.customerFk).length,
        ),
        findUnique: jest.fn(async ({ where }) => {
          const key = where.customerFk_vehicleId;
          return (
            rows.find(
              (r) => r.customerFk === key.customerFk && r.vehicleId === key.vehicleId,
            ) ?? null
          );
        }),
        createMany: jest.fn(async ({ data, skipDuplicates }) => {
          let created = 0;
          for (const d of data) {
            const exists = rows.some(
              (r) => r.customerFk === d.customerFk && r.vehicleId === d.vehicleId,
            );
            if (exists && skipDuplicates) continue;
            rows.push({ ...d, createdAt: new Date() });
            created++;
          }
          return { count: created };
        }),
        upsert: jest.fn(async ({ where, create }) => {
          const key = where.customerFk_vehicleId;
          const exists = rows.some(
            (r) => r.customerFk === key.customerFk && r.vehicleId === key.vehicleId,
          );
          if (!exists) rows.push({ ...create, createdAt: new Date() });
          return create;
        }),
        deleteMany: jest.fn(async ({ where }) => {
          const before = rows.length;
          rows = rows.filter(
            (r) =>
              !(
                r.customerFk === where.customerFk &&
                r.vehicleId === where.vehicleId
              ),
          );
          return { count: before - rows.length };
        }),
      },
    };

    const vehicles: any = {
      getPublicListItemsByIds: jest.fn(async (ids: string[]) =>
        ids.filter((id) => listable.has(id)).map(publicItem),
      ),
      isPubliclyListable: jest.fn(async (id: string) => listable.has(id)),
    };

    service = new FavoritesService(prisma, vehicles);
  }

  beforeEach(build);

  describe('scoping', () => {
    it('lists only the caller’s own saved vehicles', async () => {
      rows.push({ customerFk: CUSTOMER, vehicleId: V1, createdAt: new Date() });
      rows.push({ customerFk: 'someone-else', vehicleId: V2, createdAt: new Date() });

      const view = await service.list(CUSTOMER);
      expect(view.vehicle_ids).toEqual([V1]);
    });
  });

  describe('privacy', () => {
    it('returns the PUBLIC vehicle projection, never identity', async () => {
      rows.push({ customerFk: CUSTOMER, vehicleId: V1, createdAt: new Date() });

      const view = await service.list(CUSTOMER);
      const item = view.items[0] as unknown as Record<string, unknown>;

      for (const forbidden of [
        'chauffeur',
        'chauffeur_name',
        'chauffeur_id',
        'driver',
        'owner',
        'registration_number',
        'documents',
      ]) {
        expect(Object.keys(item)).not.toContain(forbidden);
      }
      expect(item.has_verified_chauffeur).toBe(true);
    });

    it('cannot be used to probe for unpublished fleet', async () => {
      const unlisted = '99999999-9999-4999-8999-999999999999';
      await expect(service.add(CUSTOMER, unlisted)).rejects.toThrow(/not found/i);
      expect(rows).toHaveLength(0);
    });
  });

  describe('add', () => {
    it('is idempotent — a double save leaves one row', async () => {
      await service.add(CUSTOMER, V1);
      const second = await service.add(CUSTOMER, V1);

      expect(rows).toHaveLength(1);
      expect(second.vehicle_ids).toEqual([V1]);
    });

    it('rejects a malformed vehicle id with a validation error', async () => {
      await expect(service.add(CUSTOMER, 'not-a-uuid')).rejects.toThrow(
        /invalid vehicle id/i,
      );
    });

    it('enforces the saved-vehicle cap but still allows re-saving', async () => {
      for (let i = 0; i < MAX_FAVORITES; i++) {
        rows.push({
          customerFk: CUSTOMER,
          vehicleId: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
          createdAt: new Date(),
        });
      }
      await expect(service.add(CUSTOMER, V1)).rejects.toThrow(/up to 100/i);

      // Saving an already-saved vehicle is not a new row, so it must succeed.
      const existing = rows[0].vehicleId;
      listable.add(existing);
      await expect(service.add(CUSTOMER, existing)).resolves.toBeDefined();
    });
  });

  describe('remove', () => {
    it('is idempotent for an already-removed vehicle', async () => {
      await service.add(CUSTOMER, V1);
      await service.remove(CUSTOMER, V1);
      await expect(service.remove(CUSTOMER, V1)).resolves.toBeDefined();
      expect(rows).toHaveLength(0);
    });
  });

  describe('list', () => {
    it('reports saved vehicles that are no longer publicly bookable', async () => {
      await service.add(CUSTOMER, V1);
      await service.add(CUSTOMER, V2);

      // V1 gets suspended/unlisted after being saved.
      listable.delete(V1);

      const view = await service.list(CUSTOMER);
      expect(view.total).toBe(2);
      expect(view.vehicle_ids).toEqual([V2]);
      expect(view.unavailable_count).toBe(1);
    });
  });

  describe('merge (guest shortlist → account)', () => {
    it('imports only listable vehicles and reports the rest', async () => {
      const unlisted = '99999999-9999-4999-8999-999999999999';

      const view = await service.merge(CUSTOMER, [V1, V2, unlisted, 'garbage']);

      expect(view.vehicle_ids.sort()).toEqual([V1, V2].sort());
      expect(view.ignored_vehicle_ids.sort()).toEqual(
        [unlisted, 'garbage'].sort(),
      );
    });

    it('never fails a sign-in because the guest shortlist went stale', async () => {
      const view = await service.merge(CUSTOMER, [
        '99999999-9999-4999-8999-999999999999',
      ]);
      expect(view.total).toBe(0);
      expect(view.ignored_vehicle_ids).toHaveLength(1);
    });

    it('keeps existing favourites and is idempotent on re-merge', async () => {
      await service.add(CUSTOMER, V3);
      const first = await service.merge(CUSTOMER, [V1, V3]);
      const second = await service.merge(CUSTOMER, [V1, V3]);

      expect(first.total).toBe(2);
      expect(second.total).toBe(2);
      expect(rows).toHaveLength(2);
    });

    it('de-duplicates a tampered payload', async () => {
      const view = await service.merge(CUSTOMER, [V1, V1, V1]);
      expect(view.total).toBe(1);
    });

    it('never writes more rows than the cap allows', async () => {
      for (let i = 0; i < MAX_FAVORITES; i++) {
        rows.push({
          customerFk: CUSTOMER,
          vehicleId: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
          createdAt: new Date(),
        });
      }
      const view = await service.merge(CUSTOMER, [V1, V2, V3]);
      expect(rows).toHaveLength(MAX_FAVORITES);
      expect(view.vehicle_ids).not.toContain(V1);
    });
  });
});
