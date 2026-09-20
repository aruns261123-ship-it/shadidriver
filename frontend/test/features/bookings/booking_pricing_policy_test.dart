import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_pricing_policy.dart';

void main() {
  group('BookingPricingPolicy Tests', () {
    test(
      'DevelopmentAdvancePaymentPolicy calculates configurable token percentages',
      () {
        const defaultPolicy = DevelopmentAdvancePaymentPolicy();
        expect(
          defaultPolicy.calculateAdvanceTokenPaise(1000000),
          equals(200000),
        );
        expect(defaultPolicy.advanceTokenLabel, equals('Advance Token'));

        const customPolicy = DevelopmentAdvancePaymentPolicy(
          advancePercentage: 0.15,
          advanceTokenLabel: 'Provisional 15% Token',
        );
        expect(
          customPolicy.calculateAdvanceTokenPaise(1000000),
          equals(150000),
        );
        expect(customPolicy.advanceTokenLabel, equals('Provisional 15% Token'));
      },
    );

    test(
      'DevelopmentBookingPricingPolicy computes duration tiers and overtime rates',
      () {
        const policy = DevelopmentBookingPricingPolicy();
        const basePrice = 2000000; // ₹20,000 in paise

        // Short duration (<= 4h): 70% of base
        final shortResult = policy.calculatePricing(
          basePricePaise: basePrice,
          durationHours: 4,
        );
        expect(shortResult.estimatedTotalPaise, equals(1400000));
        expect(shortResult.advanceTokenPaise, equals(280000)); // 20% of 14,000

        // Standard duration (8h): 100% of base
        final standardResult = policy.calculatePricing(
          basePricePaise: basePrice,
          durationHours: 8,
        );
        expect(standardResult.estimatedTotalPaise, equals(2000000));
        expect(standardResult.advanceTokenPaise, equals(400000));

        // Overtime (10h): base + 2 extra hours * 15% of base (300,000 * 2 = 600,000)
        final overtimeResult = policy.calculatePricing(
          basePricePaise: basePrice,
          durationHours: 10,
        );
        expect(overtimeResult.estimatedTotalPaise, equals(2600000));
        expect(overtimeResult.advanceTokenPaise, equals(520000));
      },
    );

    test('Custom configurable pricing policy overrides defaults', () {
      const customPolicy = DevelopmentBookingPricingPolicy(
        advancePaymentPolicy: DevelopmentAdvancePaymentPolicy(
          advancePercentage: 0.25,
          advanceTokenLabel: 'Premium Reservation Deposit',
        ),
        standardDurationHours: 6,
        shortPackageMultiplier: 0.80,
        overtimeRatePerHour: 0.10,
      );

      const base = 1000000;

      // <= 4h: 80% = 800,000. 25% token = 200,000
      final res4h = customPolicy.calculatePricing(
        basePricePaise: base,
        durationHours: 4,
      );
      expect(res4h.estimatedTotalPaise, equals(800000));
      expect(res4h.advanceTokenPaise, equals(200000));
      expect(res4h.advanceTokenLabel, equals('Premium Reservation Deposit'));

      // 6h: standard = 1,000,000. 25% token = 250,000
      final res6h = customPolicy.calculatePricing(
        basePricePaise: base,
        durationHours: 6,
      );
      expect(res6h.estimatedTotalPaise, equals(1000000));
      expect(res6h.advanceTokenPaise, equals(250000));

      // 8h: 2 overtime hours * 10% (100,000 * 2 = 200,000) = 1,200,000. 25% token = 300,000
      final res8h = customPolicy.calculatePricing(
        basePricePaise: base,
        durationHours: 8,
      );
      expect(res8h.estimatedTotalPaise, equals(1200000));
      expect(res8h.advanceTokenPaise, equals(300000));
    });
  });
}
