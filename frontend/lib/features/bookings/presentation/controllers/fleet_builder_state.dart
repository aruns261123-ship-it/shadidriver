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
