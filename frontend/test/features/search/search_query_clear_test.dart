import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';

void main() {
  group('VehicleSearchQuery.copyWith clear semantics', () {
    test('copyWith(null) leaves filters unchanged (no-op semantics)', () {
      const query = VehicleSearchQuery(
        pickupLocation: 'Delhi NCR',
        transmission: 'AUTOMATIC',
        minRating: 4.5,
      );

      // A plain `null` argument must be indistinguishable from "unchanged".
      final copied = query.copyWith(transmission: null, minRating: null);

      expect(copied.transmission, 'AUTOMATIC');
      expect(copied.minRating, 4.5);
      expect(copied.pickupLocation, 'Delhi NCR');
    });

    test('clear flags remove filter fields', () {
      final query = VehicleSearchQuery(
        pickupLocation: 'Delhi NCR',
        destination: 'Taj Palace',
        occasionId: 'Baraat',
        passengerCount: 4,
        eventDate: DateTime(2026, 11, 20),
        transmission: 'AUTOMATIC',
        minRating: 4.5,
        seatingCapacities: const [4],
        vehicleCategories: const ['SUV'],
        amenities: const ['Wi-Fi'],
        addonIds: const ['addon_1'],
        minPriceCents: 1000,
        maxPriceCents: 5000,
      );

      final cleared = query.copyWith(
        clearTransmission: true,
        clearMinRating: true,
        clearSeatingCapacities: true,
        clearVehicleCategories: true,
        clearAmenities: true,
        clearAddonIds: true,
        clearMinPriceCents: true,
        clearMaxPriceCents: true,
        clearDestination: true,
      );

      expect(cleared.transmission, isNull);
      expect(cleared.minRating, isNull);
      expect(cleared.seatingCapacities, isNull);
      expect(cleared.vehicleCategories, isNull);
      expect(cleared.amenities, isNull);
      expect(cleared.addonIds, isNull);
      expect(cleared.minPriceCents, isNull);
      expect(cleared.maxPriceCents, isNull);
      expect(cleared.destination, isNull);

      // Everything else is preserved.
      expect(cleared.pickupLocation, 'Delhi NCR');
      expect(cleared.occasionId, 'Baraat');
      expect(cleared.passengerCount, 4);
      expect(cleared.eventDate, DateTime(2026, 11, 20));
    });

    test('clear flag beats an explicitly supplied value', () {
      const query = VehicleSearchQuery(transmission: 'MANUAL');
      final cleared = query.copyWith(
        transmission: 'AUTOMATIC',
        clearTransmission: true,
      );
      expect(cleared.transmission, isNull);
    });

    test('boolean filters flip normally without clear flags', () {
      const query = VehicleSearchQuery(
        verifiedChauffeurOnly: true,
        availableNow: true,
      );
      final off = query.copyWith(
        verifiedChauffeurOnly: false,
        availableNow: false,
      );
      expect(off.verifiedChauffeurOnly, isFalse);
      expect(off.availableNow, isFalse);
    });

    test('equality and hashCode remain consistent after clear', () {
      const a = VehicleSearchQuery(transmission: 'MANUAL');
      final clearedA = a.copyWith(clearTransmission: true);
      const b = VehicleSearchQuery();

      expect(clearedA, equals(b));
      expect(clearedA.hashCode, b.hashCode);
    });
  });
}
