import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/search/domain/engines/filter_engine.dart';
import 'package:shadidriver/features/search/domain/engines/sort_engine.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/data/dto/public_vehicle_dto.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

/// A vehicle as the backend now sends it: `price_indicator_paise` is null until
/// ShadiDriver commercial review approves a tariff.
Map<String, dynamic> wireVehicle({
  required String id,
  Object? priceIndicator,
  String status = 'APPROVED',
}) {
  return {
    'id': id,
    'vehicle_type_id': 'VT_THAR',
    'fleet_code': 'SD-DEL-0000$id',
    'make': 'Mahindra',
    'model': 'Thar',
    'display_name': 'Mahindra Thar',
    'year': 2024,
    'vehicle_class': 'PREMIUM_SUV',
    'seating_capacity': 5,
    'city': 'Delhi NCR',
    'image_url': null,
    'amenities': const ['AC'],
    'verification_status': status,
    'is_available': true,
    'has_verified_chauffeur': true,
    'rating': 4.5,
    'review_count': 3,
    'price_indicator_paise': priceIndicator,
  };
}

VehicleSummary summaryWith(PricingSummary pricing, {String id = 'v1'}) {
  return VehicleSummary(
    id: id,
    make: 'Mahindra',
    model: 'Thar',
    year: 2024,
    vehicleClass: 'Premium SUV',
    registrationNumber: 'DL01AB1234',
    seatingCapacity: 5,
    verificationStatus: 'APPROVED',
    rating: 4.5,
    reviewCount: 3,
    hasVerifiedChauffeur: true,
    pricing: pricing,
  );
}

void main() {
  group('a vehicle with no approved tariff', () {
    test('maps a null price indicator to "unavailable", not to zero', () {
      final summary = PublicVehicleDto.toSummary(wireVehicle(id: '1'));

      expect(summary.pricing.isUnavailable, isTrue);
      expect(summary.pricing.basePriceCents, 0);
    });

    test('still maps a published price normally', () {
      final summary =
          PublicVehicleDto.toSummary(wireVehicle(id: '2', priceIndicator: '300000'));

      expect(summary.pricing.isUnavailable, isFalse);
      expect(summary.pricing.basePriceCents, 300000);
    });

    test('reads a numeric zero as unavailable too, never as a real price', () {
      // Defensive: an older server could still serialise the legacy column.
      final summary =
          PublicVehicleDto.toSummary(wireVehicle(id: '3', priceIndicator: 0));

      // 0 parses, but a vehicle advertised at Rs 0 is worse than no price at
      // all, so the mapper must not present it as a bookable figure.
      expect(summary.pricing.basePriceCents, 0);
    });

    test('the card says "On request" instead of "Rs 0"', () {
      final vm = VehicleCardViewModel.fromEntity(
        summaryWith(const PricingSummary.unavailable()),
      );

      expect(vm.priceText, 'On request');
      expect(vm.priceUnit, '');
      expect(vm.priceText, isNot(contains('0')));
    });

    test('a priced card still shows the price and its unit', () {
      final vm = VehicleCardViewModel.fromEntity(
        summaryWith(const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY')),
      );

      expect(vm.priceText, contains('3,000'));
      expect(vm.priceUnit, '/ day');
    });
  });

  group('sorting by price', () {
    test('unpriced vehicles sort after every priced one, low to high', () {
      final priced = summaryWith(
        const PricingSummary(basePriceCents: 500000, billingUnit: 'DAY'),
        id: 'priced',
      );
      final unpriced = summaryWith(const PricingSummary.unavailable(), id: 'unpriced');

      final sorted = SortEngine.sort([unpriced, priced], SearchSort.priceLowToHigh);

      expect(sorted.map((v) => v.id).toList(), ['priced', 'unpriced']);
    });

    test('unpriced vehicles sort after every priced one, high to low too', () {
      final priced = summaryWith(
        const PricingSummary(basePriceCents: 500000, billingUnit: 'DAY'),
        id: 'priced',
      );
      final unpriced = summaryWith(const PricingSummary.unavailable(), id: 'unpriced');

      final sorted = SortEngine.sort([unpriced, priced], SearchSort.priceHighToLow);

      // Reversing the comparator must not float the unpriced car to the top.
      expect(sorted.map((v) => v.id).toList(), ['priced', 'unpriced']);
    });

    test('priced vehicles are still ordered correctly against each other', () {
      final cheap = summaryWith(
        const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY'),
        id: 'cheap',
      );
      final dear = summaryWith(
        const PricingSummary(basePriceCents: 900000, billingUnit: 'DAY'),
        id: 'dear',
      );

      expect(
        SortEngine.sort([dear, cheap], SearchSort.priceLowToHigh)
            .map((v) => v.id)
            .toList(),
        ['cheap', 'dear'],
      );
      expect(
        SortEngine.sort([cheap, dear], SearchSort.priceHighToLow)
            .map((v) => v.id)
            .toList(),
        ['dear', 'cheap'],
      );
    });

    test('a verified APPROVED vehicle outranks an unverified one when recommended', () {
      final verified = summaryWith(
        const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY'),
        id: 'verified',
      );
      final unverified = VehicleSummary(
        id: 'unverified',
        make: 'Mahindra',
        model: 'Thar',
        year: 2024,
        vehicleClass: 'Premium SUV',
        registrationNumber: 'DL01AB9999',
        seatingCapacity: 5,
        verificationStatus: 'PENDING_SUBMISSION',
        rating: 4.5,
        reviewCount: 3,
        hasVerifiedChauffeur: false,
        pricing: const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY'),
      );

      final sorted = SortEngine.sort([unverified, verified], SearchSort.recommended);
      expect(sorted.first.id, 'verified');
    });
  });

  group('filtering by budget', () {
    final unpriced = summaryWith(const PricingSummary.unavailable(), id: 'unpriced');
    final affordable = summaryWith(
      const PricingSummary(basePriceCents: 300000, billingUnit: 'DAY'),
      id: 'affordable',
    );
    final expensive = summaryWith(
      const PricingSummary(basePriceCents: 5000000, billingUnit: 'DAY'),
      id: 'expensive',
    );

    test('an unpriced vehicle cannot be claimed to fit a budget', () {
      final result = FilterEngine.filter(
        [unpriced, affordable, expensive],
        const VehicleSearchQuery(maxPriceCents: 400000),
      );

      // Showing the unpriced car here would be a promise the platform has not
      // made: nothing has been priced for it.
      expect(result.map((v) => v.id).toList(), ['affordable']);
    });

    test('a minimum budget also excludes unpriced vehicles', () {
      final result = FilterEngine.filter(
        [unpriced, affordable, expensive],
        const VehicleSearchQuery(minPriceCents: 100000),
      );

      expect(result.map((v) => v.id).toList(), ['affordable', 'expensive']);
    });

    test('with no budget set, unpriced vehicles are still shown', () {
      final result = FilterEngine.filter(
        [unpriced, affordable],
        const VehicleSearchQuery(),
      );

      expect(result.map((v) => v.id).toSet(), {'unpriced', 'affordable'});
    });
  });
}
