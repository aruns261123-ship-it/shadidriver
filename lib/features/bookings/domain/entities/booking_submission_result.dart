import 'package:flutter/foundation.dart';
import 'booking_status.dart';

/// Immutable domain entity representing the server-authoritative response
/// to a customer's booking submission intent.
///
/// NOTE: The status returned is determined strictly by the server/repository.
/// The mobile client NEVER forces a "Confirmed" state upon initial submission.
@immutable
class BookingSubmissionResult {
  /// Authoritative server booking ID.
  final String bookingId;

  /// Deterministic human-readable booking reference (e.g. SD-2026-0042).
  final String bookingReference;

  /// Server-authoritative lifecycle status.
  final BookingStatus status;

  /// Timestamp when submission was processed.
  final DateTime submittedAt;

  // Itinerary Details Echoed Back
  final String vehicleId;
  final String vehicleName;
  final String vehicleClass;
  final String chauffeurId;
  final String ceremonyType;
  final String ceremonialAttire;
  final DateTime eventDate;
  final int durationHours;
  final String pickupAddress;
  final String destinationAddress;
  final String primaryContactName;
  final String primaryContactPhone;

  // Pricing & Advance Token Lock
  final int estimatedTotalPaise;
  final int advanceTokenPaise;
  final String advanceTokenLabel;

  /// Server guidance on subsequent lifecycle steps.
  final String nextStepMessage;

  /// True if this result was resolved from an existing idempotency key match.
  final bool isIdempotentReplay;

  const BookingSubmissionResult({
    required this.bookingId,
    required this.bookingReference,
    required this.status,
    required this.submittedAt,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleClass,
    required this.chauffeurId,
    required this.ceremonyType,
    required this.ceremonialAttire,
    required this.eventDate,
    required this.durationHours,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.advanceTokenLabel = 'Advance Token',
    required this.nextStepMessage,
    this.isIdempotentReplay = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookingSubmissionResult &&
          other.bookingId == bookingId &&
          other.bookingReference == bookingReference &&
          other.status == status &&
          other.isIdempotentReplay == isIdempotentReplay);

  @override
  int get hashCode =>
      Object.hash(bookingId, bookingReference, status, isIdempotentReplay);
}
