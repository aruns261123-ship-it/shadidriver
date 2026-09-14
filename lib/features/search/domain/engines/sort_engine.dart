import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

/// Pure logic for sorting vehicles based on different strategies.
abstract final class SortEngine {
  static List<VehicleSummary> sort(
    List<VehicleSummary> vehicles,
    SearchSort strategy,
  ) {
    final list = List<VehicleSummary>.from(vehicles);
    switch (strategy) {
      case SearchSort.recommended:
        return list
          ..sort((a, b) => _calculateScore(b).compareTo(_calculateScore(a)));
      case SearchSort.priceLowToHigh:
        return list..sort(
          (a, b) =>
              a.pricing.basePriceCents.compareTo(b.pricing.basePriceCents),
        );
      case SearchSort.priceHighToLow:
        return list..sort(
          (a, b) =>
              b.pricing.basePriceCents.compareTo(a.pricing.basePriceCents),
        );
      case SearchSort.nearest:
        return list..sort(
          (a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999),
        );
      case SearchSort.highestRated:
        return list..sort((a, b) => b.rating.compareTo(a.rating));
      case SearchSort.newestVehicle:
        return list..sort((a, b) => b.year.compareTo(a.year));
    }
  }

  /// Calculates a deterministic recommendation score for a vehicle.
  /// Considers rating, availability, verification, distance, and age.
  static double _calculateScore(VehicleSummary vehicle) {
    double score = 0.0;

    // Rating: 0-50 points
    score += vehicle.rating * 10;

    // Availability: 20 points
    if (vehicle.isAvailableNow) score += 20;

    // Verification: 15 points
    if (vehicle.verificationStatus == 'VERIFIED') score += 10;
    if (vehicle.hasVerifiedChauffeur) score += 5;

    // Proximity: Up to 10 points (closer is better)
    if (vehicle.distanceKm != null) {
      score += (10 - vehicle.distanceKm!).clamp(0, 10);
    }

    // Vehicle Age: Up to 5 points (newer is better, assume 2026 is current year)
    final age = 2026 - vehicle.year;
    score += (5 - age).toDouble().clamp(0, 5);

    return score;
  }
}
