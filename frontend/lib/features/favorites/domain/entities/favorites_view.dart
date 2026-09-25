import '../../../vehicles/domain/entities/vehicle_summary.dart';

/// Server state for a customer's saved vehicles.
///
/// [unavailableCount] exists because a favourite is a bookmark, not a
/// reservation: a saved vehicle can be suspended, expired or taken off the
/// catalog. Those are counted rather than silently dropped from the UI.
class FavoritesView {
  final List<VehicleSummary> vehicles;
  final Set<String> vehicleIds;
  final int total;
  final int unavailableCount;

  /// Guest shortlist entries the server could not import (unknown or unlisted).
  final List<String> ignoredVehicleIds;

  const FavoritesView({
    this.vehicles = const [],
    this.vehicleIds = const {},
    this.total = 0,
    this.unavailableCount = 0,
    this.ignoredVehicleIds = const [],
  });

  static const FavoritesView empty = FavoritesView();

  bool contains(String vehicleId) => vehicleIds.contains(vehicleId);

  /// Saved vehicles that are still bookable.
  int get availableCount => vehicles.length;

  bool get hasUnavailable => unavailableCount > 0;
}
