import { VehiclesService } from './vehicles.service';
import {
  FORBIDDEN_CUSTOMER_VEHICLE_KEYS,
  PUBLIC_VEHICLE_DETAIL_KEYS,
  PUBLIC_VEHICLE_LIST_KEYS,
} from './dto/public-vehicle.dto';

const VEHICLE_ID = '11111111-2222-3333-4444-555555555555';

/**
 * A deliberately over-populated Prisma row: it carries chauffeur and partner
 * identity (name, phone, avatar, bio), the registration plate and full document
 * rows — exactly what the public endpoints used to return. The public DTO must
 * drop all of it.
 */
function prismaRow(overrides: Record<string, unknown> = {}) {
  return {
    id: VEHICLE_ID,
    fleetCode: 'SD-VH-0001',
    vehicleTypeId: 'VT_INNOVA_CRYSTA',
    yearOfManufacture: 2023,
    color: 'Pearl White',
    registrationNumber: 'DL01AB1234',
    fuelType: 'DIESEL',
    airConditioningType: 'DUAL_CLIMATE_CONTROL',
    isVintage: false,
    city: 'Delhi NCR',
    imageUrl: 'https://cdn.example/hero.jpg',
    photoUrls: ['https://cdn.example/1.jpg'],
    amenityTags: ['Sunroof'],
    serviceAreas: ['Delhi NCR'],
    verificationStatus: 'APPROVED',
    isAvailable: true,
    isActive: true,
    basePricePaise: 2_500_000n,
    // The APPROVED tariff is the only thing that may become a customer price.
    pricingVersions: [],
    vehicleType: {
      id: 'VT_INNOVA_CRYSTA',
      displayName: 'Toyota Innova Crysta',
      make: 'Toyota',
      model: 'Innova Crysta',
      seatingCap: 7,
      vehicleClass: 'EXECUTIVE_MPV',
      imageUrl: null,
      amenityTags: ['AC'],
    },
    // --- the leak surface -------------------------------------------------
    independentDriver: {
      verificationStatus: 'APPROVED',
      user: {
        id: 'driver-user-1',
        fullName: 'Ramesh Chauhan',
        phoneNumber: '+919810000009',
        avatarUrl: 'https://cdn.example/driver-face.jpg',
      },
      bio: 'Fifteen years of ceremonial driving.',
    },
    fleetOwner: { id: 'owner-1', companyName: 'Sharma Fleet Services', drivers: [{ id: 'd1' }] },
    documents: [
      { documentType: 'COMMERCIAL_INSURANCE', verificationStatus: 'VERIFIED', expiryDate: new Date() },
    ],
    reviews: [{ overallRating: 5 }, { overallRating: 4 }],
    ...overrides,
  };
}

function makeService(rows: unknown[]): VehiclesService {
  const prisma: any = {
    vehicle: {
      findMany: jest.fn().mockResolvedValue(rows),
      findUnique: jest.fn(async ({ where }) =>
        (rows as any[]).find((r) => r.id === where.id) ?? null,
      ),
      count: jest.fn().mockResolvedValue(rows.length),
      groupBy: jest.fn().mockResolvedValue([]),
    },
    vehicleType: { findMany: jest.fn().mockResolvedValue([]) },
  };
  return new VehiclesService(prisma);
}

/** Every key path present anywhere in a JSON tree. */
function allKeys(value: unknown, prefix = ''): string[] {
  if (Array.isArray(value)) return value.flatMap((v) => allKeys(v, prefix));
  if (value && typeof value === 'object') {
    return Object.entries(value as Record<string, unknown>).flatMap(([k, v]) => [
      k,
      ...allKeys(v, `${prefix}${k}.`),
    ]);
  }
  return [];
}

describe('public vehicle contract — customer privacy', () => {
  it('GET /vehicles items contain EXACTLY the allow-listed keys', async () => {
    const service = makeService([prismaRow()]);
    const result = await service.searchVehicles({ page: 1, limit: 20 });

    expect(result.items).toHaveLength(1);
    expect(Object.keys(result.items[0]).sort()).toEqual(
      [...PUBLIC_VEHICLE_LIST_KEYS].sort(),
    );
  });

  it('GET /vehicles never leaks chauffeur or partner identity', async () => {
    const service = makeService([prismaRow()]);
    const result = await service.searchVehicles({ page: 1, limit: 20 });
    const payload = JSON.stringify(result);

    for (const key of FORBIDDEN_CUSTOMER_VEHICLE_KEYS) {
      expect(allKeys(result)).not.toContain(key);
    }
    expect(payload).not.toContain('Ramesh Chauhan');
    expect(payload).not.toContain('+919810000009');
    expect(payload).not.toContain('driver-face.jpg');
    expect(payload).not.toContain('Sharma Fleet Services');
    expect(payload).not.toContain('DL01AB1234');
  });

  it('GET /vehicles/:id contains EXACTLY the allow-listed keys', async () => {
    const service = makeService([prismaRow()]);
    const detail = await service.getVehicleById(VEHICLE_ID);

    expect(Object.keys(detail).sort()).toEqual([...PUBLIC_VEHICLE_DETAIL_KEYS].sort());
  });

  it('GET /vehicles/:id exposes document readiness only, never document rows', async () => {
    const service = makeService([prismaRow()]);
    const detail = await service.getVehicleById(VEHICLE_ID);

    expect(detail.documents_summary).toEqual({
      total: 1,
      verified: 1,
      expiring_soon: 1,
    });
    // No document type/status/expiry rows anywhere in the payload.
    expect(JSON.stringify(detail)).not.toContain('COMMERCIAL_INSURANCE');
    expect(allKeys(detail)).not.toContain('documentType');
  });

  it('exposes the verified-chauffeur trust flag as a boolean, not an identity', async () => {
    const service = makeService([prismaRow()]);
    const detail = await service.getVehicleById(VEHICLE_ID);

    expect(detail.has_verified_chauffeur).toBe(true);
  });

  it('recognises fleet-owner vehicles: verified chauffeurs in the partner fleet count', async () => {
    // No independentDriver at all — the old code excluded these vehicles from
    // allocation entirely. A partner-owned vehicle with a verified chauffeur
    // available must still read as chauffeur-backed.
    const service = makeService([
      prismaRow({ independentDriver: null, fleetOwner: { drivers: [{ id: 'd1' }] } }),
    ]);
    const detail = await service.getVehicleById(VEHICLE_ID);
    expect(detail.has_verified_chauffeur).toBe(true);
  });

  it('reports rating from published reviews only', async () => {
    const service = makeService([prismaRow({ reviews: [{ overallRating: 5 }, { overallRating: 4 }] })]);
    const detail = await service.getVehicleById(VEHICLE_ID);
    expect(detail.rating).toBe(4.5);
    expect(detail.review_count).toBe(2);
  });

  it('a vehicle that cannot be listed cannot be fetched by guessing its id', async () => {
    const service = makeService([prismaRow({ verificationStatus: 'SUSPENDED' })]);
    await expect(service.getVehicleById(VEHICLE_ID)).rejects.toThrow(/not found/i);
  });

  it('rejects a malformed vehicle id with VALIDATION_FAILED, not a 500', async () => {
    const service = makeService([]);
    await expect(service.getVehicleById('not-a-uuid')).rejects.toThrow(/invalid vehicle id/i);
  });

  // ------------------------------------------------------------- pricing

  describe('the customer price indicator', () => {
    const tariff = (overrides: Record<string, unknown> = {}) => ({
      localIncludedKm: null,
      localAmountPaise: null,
      perKmPaise: null,
      hourlyPaise: null,
      fullDayPaise: null,
      overnightPaise: null,
      outstationPerDayPaise: null,
      outstationPerKmPaise: null,
      ...overrides,
    });

    it('publishes NO price when no tariff has been approved', async () => {
      // Regression: this used to read the legacy base_price_paise column, which
      // defaults to 0, so every newly onboarded partner vehicle advertised
      // "From ₹0" to customers.
      const service = makeService([prismaRow({ pricingVersions: [] })]);
      const item = await service.getVehicleById(VEHICLE_ID);
      expect(item.price_indicator_paise).toBeNull();
    });

    it('ignores the legacy column even when it holds a value', async () => {
      const service = makeService([
        prismaRow({ basePricePaise: 2_500_000n, pricingVersions: [] }),
      ]);
      const item = await service.getVehicleById(VEHICLE_ID);
      expect(item.price_indicator_paise).not.toBe('2500000');
      expect(item.price_indicator_paise).toBeNull();
    });

    it('publishes the cheapest ENTRY amount from the approved tariff', async () => {
      const service = makeService([
        prismaRow({
          pricingVersions: [
            tariff({
              localIncludedKm: 45,
              localAmountPaise: 300_000n,
              perKmPaise: 2_000n,
              fullDayPaise: 900_000n,
              hourlyPaise: 100_000n,
            }),
          ],
        }),
      ]);
      const item = await service.getVehicleById(VEHICLE_ID);
      // The 45 km local rate is the cheapest thing a customer can actually book.
      // Per-km and per-hour rates are incremental and must not be treated as a
      // standalone price (₹1,000/hour is not "from ₹1,000").
      expect(item.price_indicator_paise).toBe('300000');
    });

    it('publishes no price when the tariff is rate-only', async () => {
      const service = makeService([
        prismaRow({ pricingVersions: [tariff({ perKmPaise: 2_000n, hourlyPaise: 100_000n })] }),
      ]);
      const item = await service.getVehicleById(VEHICLE_ID);
      expect(item.price_indicator_paise).toBeNull();
    });

    it('never treats a zero entry amount as a price', async () => {
      const service = makeService([
        prismaRow({ pricingVersions: [tariff({ localAmountPaise: 0n })] }),
      ]);
      const item = await service.getVehicleById(VEHICLE_ID);
      expect(item.price_indicator_paise).toBeNull();
    });

    it('still carries the price key, so the contract shape does not drift', async () => {
      const service = makeService([prismaRow({ pricingVersions: [] })]);
      const item = await service.getVehicleById(VEHICLE_ID);
      expect(Object.keys(item).sort()).toEqual([...PUBLIC_VEHICLE_DETAIL_KEYS].sort());
      expect(item).toHaveProperty('price_indicator_paise', null);
    });
  });
});
