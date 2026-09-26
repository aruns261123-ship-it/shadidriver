import {
  advanceFor,
  crossesMidnight,
  deriveLineQuote,
  QuoteTariff,
  serviceHours,
} from './group-booking-pricing';

const tariff = (overrides: Partial<QuoteTariff> = {}): QuoteTariff => ({
  id: 'pricing-1',
  version: 3,
  localIncludedKm: 45,
  localAmountPaise: 300_000n, // ₹3,000 / 45 km
  perKmPaise: 2_300n, // ₹23 / km
  hourlyPaise: 80_000n,
  extraHourPaise: 70_000n,
  fullDayPaise: 1_200_000n,
  overnightPaise: 1_500_000n,
  outstationPerDayPaise: 900_000n,
  outstationPerKmPaise: 1_800n,
  ...overrides,
});

describe('deriveLineQuote', () => {
  it('bills a short ceremony window hourly when an hourly rate exists', () => {
    const quote = deriveLineQuote(tariff(), 3, false);
    expect(quote.basis).toBe('HOURLY');
    expect(quote.amountPaise).toBe(240_000n); // 3 × ₹800
    expect(quote.billableHours).toBe(3);
  });

  it('rounds a partial hour UP — a 2h15 window bills 3 hours', () => {
    expect(deriveLineQuote(tariff(), 2.25, false).billableHours).toBe(3);
    expect(deriveLineQuote(tariff(), 2.25, false).amountPaise).toBe(240_000n);
  });

  it('bills a full-day window at the full-day rate, not per hour', () => {
    const quote = deriveLineQuote(tariff(), 9, false);
    expect(quote.basis).toBe('FULL_DAY');
    expect(quote.amountPaise).toBe(1_200_000n);
  });

  it('bills an overnight window at the overnight rate', () => {
    const quote = deriveLineQuote(tariff(), 6, true);
    expect(quote.basis).toBe('OVERNIGHT');
    expect(quote.amountPaise).toBe(1_500_000n);
  });

  it('treats a 12h+ window as overnight even without crossing midnight', () => {
    expect(deriveLineQuote(tariff(), 14, false).basis).toBe('OVERNIGHT');
  });

  it('falls back to the local package when no hourly rate is published', () => {
    const quote = deriveLineQuote(tariff({ hourlyPaise: null }), 3, false);
    expect(quote.basis).toBe('LOCAL_PACKAGE');
    expect(quote.amountPaise).toBe(300_000n);
    expect(quote.includedKm).toBe(45);
    expect(quote.perKmPaise).toBe(2_300n);
  });

  it('records the tariff version so a later edit provably cannot rewrite the price', () => {
    const quote = deriveLineQuote(tariff(), 3, false);
    expect(quote.tariffVersion).toBe(3);
    expect(quote.tariffId).toBe('pricing-1');
  });

  it('is UNPRICED — never ₹0 — when there is no approved tariff', () => {
    const quote = deriveLineQuote(null, 3, false);
    expect(quote.amountPaise).toBeNull();
    expect(quote.basis).toBe('UNPRICED');
  });

  it('is UNPRICED when the tariff carries no usable component', () => {
    const empty = tariff({
      hourlyPaise: null,
      localAmountPaise: null,
      fullDayPaise: null,
      overnightPaise: null,
    });
    for (const hours of [2, 8, 14]) {
      expect(deriveLineQuote(empty, hours, false).amountPaise).toBeNull();
      expect(deriveLineQuote(empty, hours, false).basis).toBe('UNPRICED');
    }
  });

  it('never auto-selects an outstation rate (it depends on a declared distance)', () => {
    const outstationOnly = tariff({
      hourlyPaise: null,
      localAmountPaise: null,
      fullDayPaise: null,
      overnightPaise: null,
    });
    expect(deriveLineQuote(outstationOnly, 10, false).basis).toBe('UNPRICED');
  });
});

describe('advance', () => {
  it('takes 25% of the quoted total, rounded down to whole paise', () => {
    expect(advanceFor(300_000n)).toBe(75_000n);
    expect(advanceFor(3_001n)).toBe(750n); // 750.25 → 750
  });
});

describe('window helpers', () => {
  it('measures service hours exactly', () => {
    expect(
      serviceHours(new Date('2026-11-20T10:00:00Z'), new Date('2026-11-20T22:30:00Z')),
    ).toBe(12.5);
  });

  it('detects a window that runs past midnight', () => {
    expect(
      crossesMidnight(new Date('2026-11-20T20:00:00Z'), new Date('2026-11-21T02:00:00Z')),
    ).toBe(true);
    expect(
      crossesMidnight(new Date('2026-11-20T20:00:00Z'), new Date('2026-11-20T23:30:00Z')),
    ).toBe(false);
  });
});
