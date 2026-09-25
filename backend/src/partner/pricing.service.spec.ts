import { PricingService } from './pricing.service';
import { PricingStatus } from '@prisma/client';

const ME = 'user-partner';
const MY_PARTNER = 'partner-1';
const OTHER_PARTNER = 'partner-2';
const MY_VEHICLE = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const THEIR_VEHICLE = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

function tariffDto(overrides: Record<string, unknown> = {}) {
  return {
    localIncludedKm: 45,
    localAmountPaise: 300000,
    perKmPaise: 2200,
    ...overrides,
  } as never;
}

describe('PricingService (partner tariff submission)', () => {
  let service: PricingService;
  let prisma: any;
  let partner: Record<string, unknown>;
  let vehicles: Record<string, unknown>[];
  let pricingRows: Record<string, unknown>[];
  let auditRows: Record<string, unknown>[];
  let nextId: number;

  beforeEach(() => {
    partner = { id: MY_PARTNER, userId: ME };
    vehicles = [
      { id: MY_VEHICLE, fleetOwnerId: MY_PARTNER, verificationStatus: 'PENDING_SUBMISSION' },
    ];
    pricingRows = [];
    auditRows = [];
    nextId = 1;

    prisma = {
      partnerProfile: {
        findUnique: jest.fn(async () => partner),
      },
      vehicle: {
        findUnique: jest.fn(async ({ where }: any) =>
          vehicles.find((v) => v.id === where.id) ?? null,
        ),
      },
      vehiclePricing: {
        findFirst: jest.fn(async ({ where, orderBy }: any) => {
          const rows = pricingRows
            .filter((r) => r.vehicleId === where.vehicleId)
            .sort((a, b) => {
              const av = Number(a.version);
              const bv = Number(b.version);
              return orderBy?.version === 'desc' ? bv - av : av - bv;
            });
          return rows[0] ?? null;
        }),
        findMany: jest.fn(async ({ where }: any) =>
          pricingRows.filter((r) => r.vehicleId === where.vehicleId),
        ),
        create: jest.fn(async ({ data }: any) => {
          const row = {
            id: `pricing-${nextId++}`,
            vehicleId: data.vehicleId,
            version: data.version,
            currency: 'INR',
            localIncludedKm: data.localIncludedKm ?? null,
            localAmountPaise: BigInt(data.localAmountPaise ?? 0),
            perKmPaise: data.perKmPaise != null ? BigInt(data.perKmPaise) : null,
            hourlyPaise: data.hourlyPaise != null ? BigInt(data.hourlyPaise) : null,
            extraHourPaise: data.extraHourPaise != null ? BigInt(data.extraHourPaise) : null,
            fullDayPaise: data.fullDayPaise != null ? BigInt(data.fullDayPaise) : null,
            overnightPaise: data.overnightPaise != null ? BigInt(data.overnightPaise) : null,
            outstationPerDayPaise:
              data.outstationPerDayPaise != null ? BigInt(data.outstationPerDayPaise) : null,
            outstationPerKmPaise:
              data.outstationPerKmPaise != null ? BigInt(data.outstationPerKmPaise) : null,
            status: data.status ?? PricingStatus.PENDING_REVIEW,
            submittedAt: new Date(),
            reviewedAt: null,
            decisionReason: null,
            effectiveFrom: data.effectiveFrom ?? null,
            ...data,
          };
          pricingRows.push(row);
          return row;
        }),
      },
      auditLog: {
        create: jest.fn(async ({ data }: any) => {
          auditRows.push(data);
          return data;
        }),
      },
      $transaction: jest.fn(async (fn: any) => fn(prisma)),
    };

    service = new PricingService(prisma);
  });

  // ---------------------------------------------------------------- ownership

  it('refuses to price another partner’s vehicle with NOT_FOUND (no existence oracle)', async () => {
    vehicles.push({ id: THEIR_VEHICLE, fleetOwnerId: OTHER_PARTNER, verificationStatus: 'APPROVED' });

    await expect(service.submitPricing(ME, THEIR_VEHICLE, tariffDto())).rejects.toThrow(
      /not found/i,
    );
    await expect(service.listPricing(ME, THEIR_VEHICLE)).rejects.toThrow(/not found/i);
  });

  it('a non-partner account cannot submit tariffs at all', async () => {
    partner = null as never;
    await expect(service.submitPricing(ME, MY_VEHICLE, tariffDto())).rejects.toThrow(
      /register as a partner/i,
    );
  });

  it('refuses to price a suspended vehicle', async () => {
    vehicles[0] = { ...vehicles[0], verificationStatus: 'SUSPENDED' };
    await expect(service.submitPricing(ME, MY_VEHICLE, tariffDto())).rejects.toThrow(
      /suspended/i,
    );
  });

  // ------------------------------------------------------------- versioning

  it('starts every submission PENDING_REVIEW and never live', async () => {
    const view = await service.submitPricing(ME, MY_VEHICLE, tariffDto());
    expect(view.status).toBe(PricingStatus.PENDING_REVIEW);
    expect(view.is_live).toBe(false);
    expect(prisma.vehiclePricing.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: PricingStatus.PENDING_REVIEW }),
      }),
    );
  });

  it('versions monotonically per vehicle, never overwriting history', async () => {
    const v1 = await service.submitPricing(ME, MY_VEHICLE, tariffDto());
    const v2 = await service.submitPricing(
      ME,
      MY_VEHICLE,
      tariffDto({ localAmountPaise: 350000 }),
    );
    expect(v1.version).toBe(1);
    expect(v2.version).toBe(2);
    expect(pricingRows).toHaveLength(2);
  });

  it('records who submitted and writes an audit row', async () => {
    await service.submitPricing(ME, MY_VEHICLE, tariffDto());
    const created = prisma.vehiclePricing.create.mock.calls[0][0].data;
    expect(created.submittedByUserId).toBe(ME);
    expect(auditRows).toHaveLength(1);
    expect(auditRows[0].action).toBe('PRICING_SUBMITTED');
    expect(auditRows[0].actorId).toBe(ME);
  });

  it('lists history newest-first and flags the live (approved) version', async () => {
    pricingRows.push(
      { id: 'p1', vehicleId: MY_VEHICLE, version: 1, status: PricingStatus.SUPERSEDED, submittedAt: new Date() },
      { id: 'p2', vehicleId: MY_VEHICLE, version: 2, status: PricingStatus.APPROVED, submittedAt: new Date() },
    );
    const result = await service.listPricing(ME, MY_VEHICLE);
    // The real Prisma orders by version desc; assert set-equality and the
    // live flag rather than depending on the mock's ordering.
    expect([...result.items.map((r: any) => r.version)].sort().reverse()).toEqual([2, 1]);
    expect(result.live_version).toBe(2);
    const live = result.items.find((r: any) => r.id === 'p2');
    expect(live?.is_live).toBe(true);
  });

  it('an APPROVED tariff survives a new submission untouched', async () => {
    pricingRows.push({
      id: 'live', vehicleId: MY_VEHICLE, version: 1, status: PricingStatus.APPROVED,
      localAmountPaise: 300000n, submittedAt: new Date(),
    });
    await service.submitPricing(ME, MY_VEHICLE, tariffDto({ localAmountPaise: 999999 }));

    const live = pricingRows.find((r) => r.id === 'live') as any;
    expect(live.status).toBe(PricingStatus.APPROVED);
    expect(live.localAmountPaise).toBe(300000n);
  });

  // ------------------------------------------------------------- sanitisation

  it.each([
    [
      'full-day below the local package',
      tariffDto({ fullDayPaise: 100000 }),
      /fullDayPaise .* cannot be lower than the local package/i,
    ],
    [
      'full-day below four hourly rates',
      tariffDto({ hourlyPaise: 125000, fullDayPaise: 400000 }),
      /fullDayPaise cannot be lower than 4 hourly rates/i,
    ],
    [
      'overnight below the full-day rate',
      tariffDto({ fullDayPaise: 900000, overnightPaise: 500000 }),
      /overnightPaise cannot be lower than the full-day rate/i,
    ],
    [
      'outstation per-km below local per-km',
      tariffDto({ outstationPerKmPaise: 1000 }),
      /outstationPerKmPaise cannot be lower than the local per-km rate/i,
    ],
  ])('rejects %s', async (_label, dto, message) => {
    await expect(service.submitPricing(ME, MY_VEHICLE, dto as never)).rejects.toThrow(message);
    expect(prisma.vehiclePricing.create).not.toHaveBeenCalled();
  });

  it('accepts a coherent full tariff and serialises paise as strings', async () => {
    const view = await service.submitPricing(
      ME,
      MY_VEHICLE,
      tariffDto({
        fullDayPaise: 900000,
        overnightPaise: 1200000,
        outstationPerDayPaise: 600000,
        outstationPerKmPaise: 2600,
      }),
    );
    expect(view.local_amount_paise).toBe('300000');
    expect(typeof view.local_amount_paise).toBe('string');
    expect(view.local_included_km).toBe(45);
    expect(view.full_day_paise).toBe('900000');
  });
});
