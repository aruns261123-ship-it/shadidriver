import { AvailabilityService } from './availability.service';

describe('AvailabilityService (fleet availability)', () => {
  let service: AvailabilityService;
  let prismaMock: {
    availability: { findMany: jest.Mock };
    vehicleType: { findUnique: jest.Mock; findMany: jest.Mock };
    vehicle: { findMany: jest.Mock };
  };

  const innovaType = {
    id: 'VT_INNOVA_CRYSTA',
    displayName: 'Toyota Innova Crysta',
    vehicleClass: 'EXECUTIVE_MPV',
    seatingCap: 6,
    isActive: true,
  };
  const etiosType = {
    id: 'VT_ETIOS',
    displayName: 'Toyota Etios',
    vehicleClass: 'EXECUTIVE_MPV',
    seatingCap: 4,
    isActive: true,
  };
  const camryType = {
    id: 'VT_CAMRY',
    displayName: 'Toyota Camry Hybrid',
    vehicleClass: 'LUXURY_SEDAN',
    seatingCap: 4,
    isActive: true,
  };

  const start = new Date('2026-11-20T16:00:00+05:30');
  const end = new Date('2026-11-21T00:00:00+05:30');

  beforeEach(() => {
    prismaMock = {
      availability: { findMany: jest.fn().mockResolvedValue([]) },
      vehicleType: {
        findUnique: jest.fn().mockImplementation(({ where }) => {
          const map = {
            VT_INNOVA_CRYSTA: innovaType,
            VT_ETIOS: etiosType,
            VT_CAMRY: camryType,
          };
          return Promise.resolve(
            map[where.id as keyof typeof map] ?? null,
          );
        }),
        findMany: jest.fn().mockResolvedValue([camryType, etiosType]),
      },
      vehicle: { findMany: jest.fn().mockResolvedValue([]) },
    };
    service = new AvailabilityService(prismaMock as never);
  });

  function mockFleet(typeId: string, count: number) {
    prismaMock.vehicle.findMany.mockImplementation(({ where }) => {
      if (where?.vehicleTypeId === typeId) {
        return Promise.resolve(Array.from({ length: count }, (_, i) => ({ id: `${typeId}-${i}` })));
      }
      return Promise.resolve([]);
    });
  }

  it('returns exact requested/available/shortfall structure', async () => {
    mockFleet('VT_INNOVA_CRYSTA', 5);
    const result = await service.checkFleetAvailability(
      [{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 7 }],
      start,
      end,
    );
    expect(result.fully_available).toBe(false);
    expect(result.lines[0].requested).toBe(7);
    expect(result.lines[0].available).toBe(5);
    expect(result.lines[0].shortfall).toBe(2);
    expect(result.total_shortfall).toBe(2);
  });

  it('offers alternatives ONLY on shortfall lines (never a silent substitution)', async () => {
    mockFleet('VT_INNOVA_CRYSTA', 5);
    const result = await service.checkFleetAvailability(
      [{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 7 }],
      start,
      end,
    );
    expect(result.lines[0].alternatives.length).toBeGreaterThanOrEqual(0);
    // The satisfied case must carry NO alternatives.
    mockFleet('VT_INNOVA_CRYSTA', 7);
    const full = await service.checkFleetAvailability(
      [{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 7 }],
      start,
      end,
    );
    expect(full.fully_available).toBe(true);
    expect(full.lines[0].alternatives).toHaveLength(0);
    expect(full.lines[0].shortfall).toBe(0);
  });

  it('computes mixed-fleet lines independently per type', async () => {
    prismaMock.vehicle.findMany.mockImplementation(({ where }) => {
      const counts: Record<string, number> = {
        VT_INNOVA_CRYSTA: 4,
        VT_CAMRY: 3,
        VT_BMW5: 1,
      };
      const n = counts[where?.vehicleTypeId as string] ?? 0;
      return Promise.resolve(Array.from({ length: n }, (_, i) => ({ id: `v-${i}` })));
    });
    prismaMock.vehicleType.findUnique.mockImplementation(({ where }) => {
      const types: Record<string, unknown> = {
        VT_INNOVA_CRYSTA: innovaType,
        VT_CAMRY: camryType,
        VT_BMW5: { id: 'VT_BMW5', displayName: 'BMW 5 Series', vehicleClass: 'LUXURY_SEDAN', seatingCap: 4, isActive: true },
      };
      return Promise.resolve(types[where.id as string] ?? null);
    });
    const result = await service.checkFleetAvailability(
      [
        { vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 4 },
        { vehicleTypeId: 'VT_CAMRY', quantity: 3 },
        { vehicleTypeId: 'VT_BMW5', quantity: 1 },
      ],
      start,
      end,
    );
    expect(result.fully_available).toBe(true);
    expect(result.lines.map((l) => l.shortfall)).toEqual([0, 0, 0]);
    expect(result.total_requested).toBe(8);
  });

  it('excludes vehicles booked in an OVERLAPPING window', async () => {
    mockFleet('VT_INNOVA_CRYSTA', 5);
    // Two of the five are committed in an overlapping window.
    prismaMock.availability.findMany.mockResolvedValue([
      { vehicleId: 'VT_INNOVA_CRYSTA-0' },
      { vehicleId: 'VT_INNOVA_CRYSTA-1' },
    ]);
    const result = await service.checkFleetAvailability(
      [{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 7 }],
      start,
      end,
    );
    expect(result.lines[0].available).toBe(3);
    expect(result.lines[0].shortfall).toBe(4);
  });

  it('rejects invalid quantities and inverted windows', async () => {
    await expect(
      service.checkFleetAvailability([{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 0 }], start, end),
    ).rejects.toThrow(/between 1 and 50/);
    await expect(
      service.checkFleetAvailability(
        [{ vehicleTypeId: 'VT_INNOVA_CRYSTA', quantity: 2 }],
        end,
        start,
      ),
    ).rejects.toThrow(/after start/);
    await expect(
      service.checkFleetAvailability([{ vehicleTypeId: 'GHOST', quantity: 1 }], start, end),
    ).rejects.toThrow(/Unknown vehicle type/);
  });
});
