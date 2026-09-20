import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/search/domain/engines/filter_engine.dart';
import 'package:shadidriver/features/search/domain/engines/sort_engine.dart';
import 'package:shadidriver/features/vehicles/domain/entities/pricing_summary.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

void main() {
  final mockVehicles = [
    VehicleSummary(
      id: '1',
      make: 'BMW',
      model: '5 Series',
      year: 2025,
      vehicleClass: 'Luxury',
      registrationNumber: 'DL1',
      seatingCapacity: 4,
      verificationStatus: 'VERIFIED',
      rating: 4.9,
      transmission: 'AUTOMATIC',
      isAvailableNow: true,
      pricing: const PricingSummary(
        basePriceCents: 2000000,
        billingUnit: 'DAY',
      ),
    ),
    VehicleSummary(
      id: '2',
      make: 'Maruti',
      model: 'Swift',
      year: 2020,
      vehicleClass: 'Economy',
      registrationNumber: 'DL2',
      seatingCapacity: 5,
      verificationStatus: 'PENDING',
      rating: 4.0,
      transmission: 'MANUAL',
      isAvailableNow: false,
      pricing: const PricingSummary(basePriceCents: 500000, billingUnit: 'DAY'),
    ),
  ];

  group('FilterEngine', () {
    test('filters by category', () {
      const query = VehicleSearchQuery(vehicleCategories: ['Luxury']);
      final results = FilterEngine.filter(mockVehicles, query);
      expect(results.length, 1);
      expect(results[0].make, 'BMW');
    });

    test('filters by price', () {
      const query = VehicleSearchQuery(maxPriceCents: 1000000);
      final results = FilterEngine.filter(mockVehicles, query);
      expect(results.length, 1);
      expect(results[0].make, 'Maruti');
    });

    test('filters by availability now', () {
      const query = VehicleSearchQuery(availableNow: true);
      final results = FilterEngine.filter(mockVehicles, query);
      expect(results.length, 1);
      expect(results[0].id, '1');
    });

    test('filters by transmission', () {
      const query = VehicleSearchQuery(transmission: 'MANUAL');
      final results = FilterEngine.filter(mockVehicles, query);
      expect(results.length, 1);
      expect(results[0].transmission, 'MANUAL');
    });
  });

  group('SortEngine', () {
    test('sorts by price ascending', () {
      final results = SortEngine.sort(mockVehicles, SearchSort.priceLowToHigh);
      expect(results[0].make, 'Maruti');
    });

    test(
      'sorts by recommended (BMW should be higher due to rating/availability)',
      () {
        final results = SortEngine.sort(mockVehicles, SearchSort.recommended);
        expect(results[0].make, 'BMW');
      },
    );
  });
}
