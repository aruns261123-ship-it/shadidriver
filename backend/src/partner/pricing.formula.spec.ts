import { derivePerKmPaise } from './pricing.service';

describe('distance-rate formula (server-owned pricing)', () => {
  it('derives the fixed formula: fuel ÷ mileage + 10', () => {
    // The spec example: ₹95 ÷ 8 + ₹10 = ₹21.875/km → 2188 paise (rounded).
    expect(derivePerKmPaise(95, 8)).toBe(BigInt(Math.round(21.875 * 100)));
  });

  it('handles fractional mileage', () => {
    // ₹100 ÷ 12.5 + 10 = ₹18/km → 1800 paise.
    expect(derivePerKmPaise(100, 12.5)).toBe(1800n);
  });

  it('never returns a fractional paisa', () => {
    // ₹88.88 ÷ 7.7 + 10 = 21.542857… → 2154.28… rounds to 2154 paise.
    expect(derivePerKmPaise(88.88, 7.7)).toBe(2154n);
  });

  it('floors at the ₹10 platform component (high mileage still charges it)', () => {
    // ₹60 ÷ 60 + 10 = ₹11/km.
    expect(derivePerKmPaise(60, 60)).toBe(1100n);
  });
});
