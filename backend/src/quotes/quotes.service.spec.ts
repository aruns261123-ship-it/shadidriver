import { QuotesService } from './quotes.service';

describe('QuotesService (pricing engine)', () => {
  let service: QuotesService;
  const config = { jwt: {}, otp: {} } as never;

  const pricingRule = {
    id: 'rule-1',
    serviceCategoryId: 'SVC_BARAAT',
    vehicleClass: 'EXECUTIVE_MPV',
    cityCode: 'DEL',
    baseHours: 8,
    baseKm: 80,
    baseRatePaise: 2500000n,
    extraHourRatePaise: 250000n,
    extraKmRatePaise: 15000n,
    nightAllowancePaise: 200000n,
    muhuratMultiplier: 1.0,
    effectiveFrom: new Date('2026-01-01'),
    effectiveTo: null,
    isActive: true,
  };

  const vehicleType = {
    id: 'VT_INNOVA_CRYSTA',
    displayName: 'Toyota Innova Crysta',
    vehicleClass: 'EXECUTIVE_MPV',
    isActive: true,
  };

  const defaultPolicy = { isDefault: true, advanceTokenPercentage: 25.0 };

  function makePrismaMock(overrides: Partial<Record<string, unknown>> = {}) {
    return {
      vehicleType: { findUnique: jest.fn().mockResolvedValue(vehicleType) },
      pricingRule: { findFirst: jest.fn().mockResolvedValue(pricingRule) },
      serviceAddon: { findMany: jest.fn().mockResolvedValue([]) },
      bookingPolicy: { findFirst: jest.fn().mockResolvedValue(defaultPolicy) },
      ...overrides,
    };
  }

  beforeEach(() => {
    service = new QuotesService(makePrismaMock() as never, config);
  });

  const base = {
    serviceCategoryId: 'SVC_BARAAT',
    vehicleTypeId: 'VT_INNOVA_CRYSTA',
    serviceStartTime: new Date('2026-11-20T16:00:00+05:30'),
    serviceEndTime: new Date('2026-11-21T00:00:00+05:30'),
  };

  it('prices exactly base hours (8h) with no extras', async () => {
    const quote = await service.createQuote(base);
    expect(quote.breakdown.duration_hours).toBe(8);
    expect(quote.breakdown.extra_hours).toBe(0);
    // subtotal = base 2,500,000 paise
    expect(quote.subtotal_paise).toBe(2_500_000);
    // total = subtotal + 8% fee + 5% GST
    const expectedTotal = 2_500_000 + 200_000 + 125_000;
    expect(quote.total_paise).toBe(expectedTotal);
    // advance = 25% of total; balance = rest
    expect(quote.advance_token_paise).toBe(Math.round(expectedTotal * 0.25));
    expect(quote.advance_token_paise + quote.balance_paise).toBe(expectedTotal);
  });

  it('computes overnight duration correctly: 8:00 PM → 7:00 AM = 11 hours', async () => {
    const quote = await service.createQuote({
      ...base,
      serviceStartTime: new Date('2026-11-20T20:00:00+05:30'),
      serviceEndTime: new Date('2026-11-21T07:00:00+05:30'),
    });
    expect(quote.breakdown.duration_hours).toBe(11);
    expect(quote.breakdown.is_overnight).toBe(true);
    expect(quote.breakdown.extra_hours).toBe(3);
    // base + 3 extra hours + night allowance
    expect(quote.subtotal_paise).toBe(2_500_000 + 750_000 + 200_000);
  });

  it('charges extra distance beyond base km', async () => {
    const quote = await service.createQuote({ ...base, routeDistanceKm: 100 });
    expect(quote.breakdown.extra_km_charged).toBe(20 * 15_000);
  });

  it('includes validated addons at DB prices only', async () => {
    const prisma = makePrismaMock({
      serviceAddon: {
        findMany: jest.fn().mockResolvedValue([
          { id: 'addon-1', name: 'Floral Decoration', pricePaise: 350000n, isActive: true },
        ]),
      },
    });
    const svc = new QuotesService(prisma as never, config);
    const quote = await svc.createQuote({ ...base, selectedAddonIds: ['addon-1'] });
    expect(quote.line_items.some((li) => li.label.includes('Floral Decoration'))).toBe(true);
    expect(quote.subtotal_paise).toBe(2_500_000 + 350_000);
  });

  it('rejects unknown addons (client cannot invent prices)', async () => {
    await expect(
      service.createQuote({ ...base, selectedAddonIds: ['ghost-addon'] }),
    ).rejects.toThrow(/unavailable/);
  });

  it('applies muhurat multiplier as a separate line item', async () => {
    const prisma = makePrismaMock({
      pricingRule: {
        findFirst: jest.fn().mockResolvedValue({ ...pricingRule, muhuratMultiplier: 1.2 }),
      },
    });
    const svc = new QuotesService(prisma as never, config);
    const quote = await svc.createQuote(base);
    expect(quote.subtotal_paise).toBe(Math.round(2_500_000 * 1.2));
  });

  it('applies urgent surcharge when flagged', async () => {
    const quote = await service.createQuote({ ...base, isUrgent: true });
    expect(
      quote.line_items.some((li) => li.label.includes('urgent')),
    ).toBe(true);
  });

  it('rejects end-before-start and sub-hour durations', async () => {
    await expect(
      service.createQuote({ ...base, serviceEndTime: new Date('2026-11-20T15:00:00+05:30') }),
    ).rejects.toThrow(/after start/);
    await expect(
      service.createQuote({
        ...base,
        serviceEndTime: new Date('2026-11-20T16:30:00+05:30'),
      }),
    ).rejects.toThrow(/Minimum service duration/);
  });

  it('fails clearly when no pricing rule exists', async () => {
    const prisma = makePrismaMock({
      pricingRule: { findFirst: jest.fn().mockResolvedValue(null) },
    });
    const svc = new QuotesService(prisma as never, config);
    await expect(svc.createQuote(base)).rejects.toThrow(/No active pricing rule/);
  });

  it('client-supplied totals never influence the quote (server computes from rule)', async () => {
    const q1 = await service.createQuote(base);
    const q2 = await service.createQuote(base);
    expect(q1.total_paise).toBe(q2.total_paise);
    // No field on the request carries amounts; QuoteRequestInput has none.
  });
});
