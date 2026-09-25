import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

/// Pure logic for filtering vehicles based on a search query.
abstract final class FilterEngine {
  static List<VehicleSummary> filter(
    List<VehicleSummary> vehicles,
    VehicleSearchQuery query,
  ) {
    return vehicles.where((vehicle) {
      // 1. Vehicle Categories
      if (query.vehicleCategories != null &&
          query.vehicleCategories!.isNotEmpty &&
          !query.vehicleCategories!.contains(vehicle.vehicleClass)) {
        return false;
      }

      // 2. Model Year Range
      if (query.minModelYear != null && vehicle.year < query.minModelYear!) {
        return false;
      }
      if (query.maxModelYear != null && vehicle.year > query.maxModelYear!) {
        return false;
      }

      // 3. Price Range
      //
      // A vehicle with no approved tariff has no price, so it cannot be claimed
      // to satisfy a budget. Filtering on the zero placeholder would show every
      // unpriced car to someone searching under Rs 1,000.
      final priced = !vehicle.pricing.isUnavailable;
      if (query.minPriceCents != null || query.maxPriceCents != null) {
        if (!priced) return false;
        final price = vehicle.pricing.basePriceCents;
        if (query.minPriceCents != null && price < query.minPriceCents!) {
          return false;
        }
        if (query.maxPriceCents != null && price > query.maxPriceCents!) {
          return false;
        }
      }

      // 4. Seating Capacities
      if (query.seatingCapacities != null &&
          query.seatingCapacities!.isNotEmpty &&
          !query.seatingCapacities!.contains(vehicle.seatingCapacity)) {
        return false;
      }

      // 5. Transmission
      if (query.transmission != null &&
          vehicle.transmission != null &&
          vehicle.transmission != query.transmission) {
        return false;
      }

      // 6. Rating
      if (query.minRating != null && vehicle.rating < query.minRating!) {
        return false;
      }

      // 7. Distance
      if (query.maxDistanceKm != null &&
          vehicle.distanceKm != null &&
          vehicle.distanceKm! > query.maxDistanceKm!) {
        return false;
      }

      // 8. Verification
      if (query.verifiedChauffeurOnly && !vehicle.hasVerifiedChauffeur) {
        return false;
      }
      if (query.verifiedVehicleOnly &&
          vehicle.verificationStatus != 'VERIFIED') {
        return false;
      }

      // 9. Availability
      if (query.availableNow && !vehicle.isAvailableNow) {
        return false;
      }

      // 10. Amenities
      if (query.amenities != null && query.amenities!.isNotEmpty) {
        final vehicleAmenities = vehicle.amenities;
        for (final amenity in query.amenities!) {
          if (!vehicleAmenities.contains(amenity)) return false;
        }
      }

      // 11. Ceremonial occasion
      final occasion = query.occasionId;
      if (occasion != null && occasion.trim().isNotEmpty) {
        if (!_matchesOccasion(vehicle, occasion.trim())) return false;
      }

      return true;
    }).toList();
  }

  /// Case-insensitive occasion match with substring tolerance so that
  /// 'Guest Transportation' matches 'Guest Transport' and package labels
  /// like 'Royal Baraat' match a vehicle suited for 'Baraat'.
  static bool _matchesOccasion(VehicleSummary vehicle, String occasion) {
    final needle = occasion.toLowerCase();
    return vehicle.suitableCeremonies.any((ceremony) {
      final hay = ceremony.toLowerCase();
      return hay == needle || hay.startsWith(needle) || needle.startsWith(hay);
    });
  }
}
