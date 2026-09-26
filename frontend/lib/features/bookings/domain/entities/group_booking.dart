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
  ///
  /// The customer-facing payload does not echo the contact back — it is the
  /// caller's own record — so API-sourced bookings leave this empty.
  final String primaryContactName;

  /// Primary host phone number (see [primaryContactName]).
  final String primaryContactPhone;

  /// Aggregated estimated total price across all vehicle assignments in paise.
  ///
  /// null = not quoted yet. The backend returns null (never 0) while the
  /// reserved vehicles have no approved tariff or operations has not quoted,
  /// and the UI renders that as "On request".
  final int? estimatedTotalPaise;

  /// Aggregated advance token required in paise (null while unquoted).
  final int? advanceTokenPaise;

  /// Customer requirements captured with the request (optional).
  final List<String> requirements;

  /// PHONE | WHATSAPP | EMAIL | PHONE_WHATSAPP — how operations will contact.
  final String communicationPreference;

  /// Optimistic-concurrency version, so a stale view can be detected.
  final int version;

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
    this.primaryContactName = '',
    this.primaryContactPhone = '',
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.requirements = const [],
    this.communicationPreference = 'PHONE',
    this.version = 1,
    this.advanceTokenLabel = 'Advance Token',
    required this.createdAt,
  });

  /// True while the server has not produced a complete price for this booking.
  bool get quotePending => estimatedTotalPaise == null;

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
