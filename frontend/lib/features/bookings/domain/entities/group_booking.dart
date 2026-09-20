import 'package:flutter/foundation.dart';
import 'booking_status.dart';
import 'customer_fleet_intent.dart';
import 'vehicle_assignment.dart';

/// Immutable domain model representing a Parent Group / Multi-Vehicle Ceremonial Booking.
///
/// Follows the hierarchical architecture:
/// Parent Booking (Group)
///     ↓
/// Multiple Vehicle Assignments (Units)
@immutable
class GroupBooking {
  /// Unique parent booking identifier.
  final String parentBookingId;

  /// Human-readable booking reference (e.g. 'SD-GRP-2026-0042').
  final String bookingReference;

  /// Overall lifecycle status for the group booking.
  final BookingStatus status;

  /// Original customer fleet composition intent.
  final CustomerFleetIntent customerIntent;

  /// Total number of passengers / ceremonial guests accommodated.
  final int totalPassengers;

  /// Total count of assigned vehicles in the convoy.
  final int totalVehicles;

  /// Individual vehicle and chauffeur assignments under this parent booking.
  final List<VehicleAssignment> assignments;

  /// Event / ceremony type (e.g. 'Baraat Procession', 'VIP Airport Transfer').
  final String ceremonyType;

  /// Service start datetime.
  final DateTime serviceStartDateTime;

  /// Service end datetime.
  final DateTime serviceEndDateTime;

  /// City of operation.
  final String city;

  /// Primary pickup location.
  final String pickupAddress;

  /// Primary destination / venue address.
  final String destinationAddress;

  /// Primary host contact name.
  final String primaryContactName;

  /// Primary host phone number.
  final String primaryContactPhone;

  /// Aggregated estimated total price across all vehicle assignments in paise.
  final int estimatedTotalPaise;

  /// Aggregated advance token required in paise.
  final int advanceTokenPaise;

  /// Advance token label.
  final String advanceTokenLabel;

  /// Creation timestamp.
  final DateTime createdAt;

  const GroupBooking({
    required this.parentBookingId,
    required this.bookingReference,
    required this.status,
    required this.customerIntent,
    required this.totalPassengers,
    required this.totalVehicles,
    required this.assignments,
    required this.ceremonyType,
    required this.serviceStartDateTime,
    required this.serviceEndDateTime,
    required this.city,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.advanceTokenLabel = 'Advance Token',
    required this.createdAt,
  });

  /// Total seating capacity provided across all active assignments.
  int get totalAllocatedCapacity =>
      assignments.fold<int>(0, (sum, a) => sum + a.capacity);

  /// True if the total capacity satisfies or exceeds the required passenger count.
  bool get isCapacitySufficient => totalAllocatedCapacity >= totalPassengers;

  /// Helper to get assignments grouped by vehicle model.
  Map<String, List<VehicleAssignment>> get assignmentsByModel {
    final map = <String, List<VehicleAssignment>>{};
    for (final assignment in assignments) {
      map.putIfAbsent(assignment.vehicleModel, () => []).add(assignment);
    }
    return map;
  }
}
