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
  ///
  /// LEGACY: chauffeur identity is internal. The ShadiDriver backend never
  /// sends a chauffeur name to a customer payload, so this stays null for all
  /// API-sourced assignments — use [chauffeurAssigned] instead.
  final String? chauffeurName;

  /// True when operations has internally committed a chauffeur to this unit.
  /// Deliberately a boolean: the customer is told a chauffeur is arranged,
  /// never who it is.
  final bool chauffeurAssigned;

  /// Monetary price allocated to this vehicle assignment in paise.
  ///
  /// null = operations has not quoted this unit yet ("on request").
  final int? pricePaise;

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
    this.chauffeurAssigned = false,
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
    bool? chauffeurAssigned,
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
      chauffeurAssigned: chauffeurAssigned ?? this.chauffeurAssigned,
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
