import 'package:flutter/foundation.dart';

/// One line of the customer's fleet composition request.
@immutable
class FleetLineState {
  final String vehicleTypeId;
  final String displayName;
  final String vehicleClass;
  final int seatingCapacity;
  final int quantity;

  const FleetLineState({
    required this.vehicleTypeId,
    required this.displayName,
    required this.vehicleClass,
    required this.seatingCapacity,
    required this.quantity,
  });

  /// Maps one entry of the public vehicle-TYPE wire format
  /// (`GET /api/v1/vehicles/types`) onto a composition line at quantity 0.
  ///
  /// The backend speaks **snake_case**; this used to read camelCase keys, so
  /// every type silently lost its class and fell back to 4 seats — the review
  /// screen rendered "4 seats • " for a 6-seat Executive MPV. The camelCase
  /// names survive only as a tolerant fallback.
  factory FleetLineState.fromVehicleTypeJson(Map<String, dynamic> json) {
    return FleetLineState(
      vehicleTypeId: (json['id'] as String?) ?? '',
      displayName:
          (json['display_name'] as String?) ??
          (json['displayName'] as String?) ??
          '',
      vehicleClass:
          (json['vehicle_class'] as String?) ??
          (json['vehicleClass'] as String?) ??
          '',
      seatingCapacity:
          (json['seating_capacity'] as num?)?.toInt() ??
          (json['seatingCap'] as num?)?.toInt() ??
          4,
      quantity: 0,
    );
  }

  FleetLineState copyWith({int? quantity}) => FleetLineState(
        vehicleTypeId: vehicleTypeId,
        displayName: displayName,
        vehicleClass: vehicleClass,
        seatingCapacity: seatingCapacity,
        quantity: quantity ?? this.quantity,
      );
}

/// The subset of a composition the customer actually asked for.
///
/// `GroupBookingState.lines` doubles as the vehicle-type CATALOG with a
/// per-type quantity (the controller is seeded with the whole catalog at
/// quantity 0), so a zero-quantity entry is NOT a selection — it is an
/// unselected type. Everything customer-facing filters through here.
extension SelectedFleetLines on Iterable<FleetLineState> {
  List<FleetLineState> get selected =>
      where((l) => l.quantity > 0).toList(growable: false);
}
