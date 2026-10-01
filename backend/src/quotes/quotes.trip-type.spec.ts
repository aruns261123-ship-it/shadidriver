import { TripType } from '../common/domain/trip-type';
import { QuotesService } from './quotes.service';

/**
 * Regression: the trip direction the customer chose MUST reach the pricing
 * engine and change the server quote — ONE_WAY bills pickup→destination,
 * ROUND_TRIP (Both Way) bills it twice. The client cannot produce either
 * number; it only echoes the quote back.
 */
describe('QuotesService — trip type affects the server quote', () => {
  const buildService = () => {
    const rule = {
      id: 'rule-1',
      serviceCategoryId: 'SVC_BARAAT',
      vehicleClass: 'EXECUTIVE_MPV',
      cityCode: 'DEL',
      isActive: true,
      effectiveFrom: new Date(0),
      effectiveTo: null,
      baseRatePaise: 2_500_00n,
      baseHours: 8,
      extraHourRatePaise: 250_00n,
      baseKm: 40,
      extraKmRatePaise: 22_00n,
      nightAllowancePaise: 0n,
      muhuratMultiplier: 1.0,
    };
    const prisma = {
      vehicleType: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'VT_INNOVA_CRYSTA',
          isActive: true,
          vehicleClass: 'EXECUTIVE_MPV',
          displayName: 'Toyota Innova Crysta',
        }),
      },
      vehicle: { findUnique: jest.fn().mockResolvedValue(null) },
      pricingRule: { findFirst: jest.fn().mockResolvedValue(rule) },
      serviceAddon: { findMany: jest.fn().mockResolvedValue([]) },
      bookingPolicy: { findFirst: jest.fn().mockResolvedValue(null) },
    } as never;
    const config = {} as never;
    return { service: new QuotesService(prisma, config), rule };
  };

  const baseInput = {
    serviceCategoryId: 'SVC_BARAAT',
    vehicleTypeId: 'VT_INNOVA_CRYSTA',
    city: 'Delhi NCR',
    serviceStartTime: new Date('2026-11-20T16:00:00Z'),
    serviceEndTime: new Date('2026-11-21T00:00:00Z'),
    routeDistanceKm: 30,
  };

  it('ONE_WAY quotes 0 extra km when the route fits inside baseKm', async () => {
    const { service } = buildService();
    const quote = await service.createQuote({ ...baseInput, tripType: TripType.ONE_WAY });
    expect(quote.trip_type).toBe('ONE_WAY');
    expect(quote.breakdown.billable_distance_km).toBeCloseTo(30);
    expect(quote.breakdown.extra_km_charged).toBe(0);
  });

  it('ROUND_TRIP bills the route twice (60km) and charges the extra 20km', async () => {
    const { service } = buildService();
    const quote = await service.createQuote({ ...baseInput, tripType: TripType.ROUND_TRIP });
    expect(quote.trip_type).toBe('ROUND_TRIP');
    expect(quote.breakdown.route_distance_km).toBeCloseTo(30);
    expect(quote.breakdown.billable_distance_km).toBeCloseTo(60);
    expect(quote.breakdown.extra_km_charged).toBe(Math.round(20 * 2200));
    // The round trip must cost strictly more than the one way for the same car.
    const oneWay = await service.createQuote({ ...baseInput, tripType: TripType.ONE_WAY });
    expect(quote.total_paise).toBeGreaterThan(oneWay.total_paise);
  });

  it('validation rejects a submission whose direction changed after the quote', () => {
    const { service } = buildService();
    expect(() =>
      service.validateTripTypeMatches('ONE_WAY', TripType.ROUND_TRIP),
    ).toThrow(/Re-quote/);
    expect(() =>
      service.validateTripTypeMatches('ROUND_TRIP', TripType.ROUND_TRIP),
    ).not.toThrow();
  });
});
