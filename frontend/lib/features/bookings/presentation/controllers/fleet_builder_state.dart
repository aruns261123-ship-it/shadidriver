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
