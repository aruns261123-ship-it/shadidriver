import 'package:flutter/foundation.dart';

/// Immutable domain entity representing an individual vehicle assignment within
/// a multi-vehicle group ceremonial booking.
///
/// Corresponds to the hierarchy:
/// Parent Booking -> Multiple Vehicle Assignments
@immutable
class VehicleAssignment {
  /// Unique identifier for this individual vehicle assignment.
  final String assignmentId;

  /// Reference to the parent group booking.
  final String parentBookingId;

  /// Vehicle unique identifier.
  final String vehicleId;

  /// Vehicle display name (e.g. 'Toyota Innova Crysta #1', 'BMW 5 Series #2').
  final String vehicleName;

  /// Vehicle model / tier (e.g. 'Toyota Innova Crysta', 'BMW 5 Series').
  final String vehicleModel;

  /// Seating capacity for ceremonial guests.
  final int capacity;

  /// Fleet partner or owner agency (e.g. 'PB Ceremonial Fleet', 'Royal Heritage Agency').
  final String ownerName;

  /// Assigned chauffeur ID if assigned.
  final String? chauffeurId;

  /// Assigned chauffeur display name.
  final String? chauffeurName;

  /// Monetary price allocated to this vehicle assignment in paise.
  final int pricePaise;

  /// Assignment operational status (e.g. 'PENDING', 'ASSIGNED', 'DISPATCHED', 'COMPLETED').
  final String status;

  const VehicleAssignment({
    required this.assignmentId,
    required this.parentBookingId,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleModel,
    required this.capacity,
    required this.ownerName,
    this.chauffeurId,
    this.chauffeurName,
    required this.pricePaise,
    this.status = 'ASSIGNED',
  });

  VehicleAssignment copyWith({
    String? assignmentId,
    String? parentBookingId,
    String? vehicleId,
    String? vehicleName,
    String? vehicleModel,
    int? capacity,
    String? ownerName,
    String? chauffeurId,
    String? chauffeurName,
    int? pricePaise,
    String? status,
  }) {
    return VehicleAssignment(
      assignmentId: assignmentId ?? this.assignmentId,
      parentBookingId: parentBookingId ?? this.parentBookingId,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      capacity: capacity ?? this.capacity,
      ownerName: ownerName ?? this.ownerName,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      chauffeurName: chauffeurName ?? this.chauffeurName,
      pricePaise: pricePaise ?? this.pricePaise,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleAssignment &&
          other.assignmentId == assignmentId &&
          other.parentBookingId == parentBookingId &&
          other.vehicleId == vehicleId &&
          other.status == status);

  @override
  int get hashCode =>
      Object.hash(assignmentId, parentBookingId, vehicleId, status);
}
