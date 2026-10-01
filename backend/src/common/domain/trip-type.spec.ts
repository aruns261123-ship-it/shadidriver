import { TripType, billableDistanceKm, parseTripType } from './trip-type';

describe('TripType (canonical trip direction)', () => {
  it('exposes exactly the wire values the client contract declares', () => {
    expect(TripType.ONE_WAY).toBe('ONE_WAY');
    expect(TripType.ROUND_TRIP).toBe('ROUND_TRIP');
  });

  it('bills ONE_WAY as the one-way route distance', () => {
    expect(billableDistanceKm(24.5, TripType.ONE_WAY)).toBeCloseTo(24.5);
  });

  it('bills ROUND_TRIP (Both Way) as the route × 2 — the server rule', () => {
    expect(billableDistanceKm(24.5, TripType.ROUND_TRIP)).toBeCloseTo(49);
  });

  it('treats a missing distance as 0 (base fare only)', () => {
    expect(billableDistanceKm(undefined, TripType.ROUND_TRIP)).toBe(0);
  });

  it('defaults to ONE_WAY for unknown/blank values', () => {
    expect(parseTripType(undefined)).toBe(TripType.ONE_WAY);
    expect(parseTripType('BOTH_WAY')).toBe(TripType.ONE_WAY);
    expect(parseTripType('round_trip')).toBe(TripType.ROUND_TRIP);
  });
});
