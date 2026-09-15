import 'package:flutter/foundation.dart';
import 'booking_draft.dart';

/// Immutable domain model representing customer submission intent.
///
/// NOTE: This object carries the customer's requested ceremonial itinerary,
/// explicit pricing terms, and an idempotency key to prevent duplicate bookings.
/// It does NOT force server state.
@immutable
class BookingSubmissionRequest {
  final String draftId;
  final String vehicleId;
  final String vehicleName;
  final String vehicleClass;
  final String chauffeurId;

  // Event & Ceremony
  final String ceremonyType;
  final String ceremonialAttire;
  final String specialInstructions;

  // Date & Timing
  final DateTime eventDate;
  final int startTimeHour;
  final int startTimeMinute;
  final int durationHours;

  // Route & Locations
  final String city;
  final String pickupAddress;
  final String destinationAddress;
  final String venueName;
  final String landmark;

  // Host & Passenger Details
  final String primaryContactName;
  final String primaryContactPhone;
  final String? alternateContactPhone;
  final int passengerCount;

  // Explicit Policy-Derived Pricing
  final int basePricePaise;
  final int estimatedTotalPaise;
  final int advanceTokenPaise;
  final String advanceTokenLabel;

  /// Unique client-generated token ensuring idempotent submission.
  final String idempotencyKey;

  const BookingSubmissionRequest({
    required this.draftId,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleClass,
    required this.chauffeurId,
    required this.ceremonyType,
    required this.ceremonialAttire,
    this.specialInstructions = '',
    required this.eventDate,
    required this.startTimeHour,
    required this.startTimeMinute,
    required this.durationHours,
    required this.city,
    required this.pickupAddress,
    required this.destinationAddress,
    this.venueName = '',
    this.landmark = '',
    required this.primaryContactName,
    required this.primaryContactPhone,
    this.alternateContactPhone,
    required this.passengerCount,
    required this.basePricePaise,
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.advanceTokenLabel = 'Advance Token',
    required this.idempotencyKey,
  });

  /// Factory creating submission request from a validated [BookingDraft].
  factory BookingSubmissionRequest.fromDraft(
    BookingDraft draft, {
    required String idempotencyKey,
  }) {
    return BookingSubmissionRequest(
      draftId: draft.id,
      vehicleId: draft.vehicleId,
      vehicleName: draft.vehicleName,
      vehicleClass: draft.vehicleClass,
      chauffeurId: draft.chauffeurId,
      ceremonyType: draft.ceremonyType,
      ceremonialAttire: draft.ceremonialAttire,
      specialInstructions: draft.specialInstructions,
      eventDate: draft.eventDate,
      startTimeHour: draft.startTime.hour,
      startTimeMinute: draft.startTime.minute,
      durationHours: draft.durationHours,
      city: draft.city,
      pickupAddress: draft.pickupAddress,
      destinationAddress: draft.destinationAddress,
      venueName: draft.venueName,
      landmark: draft.landmark,
      primaryContactName: draft.primaryContactName,
      primaryContactPhone: draft.primaryContactPhone,
      alternateContactPhone: draft.alternateContactPhone,
      passengerCount: draft.passengerCount,
      basePricePaise: draft.basePricePaise,
      estimatedTotalPaise: draft.estimatedTotalPaise,
      advanceTokenPaise: draft.advanceTokenPaise,
      advanceTokenLabel: draft.advanceTokenLabel,
      idempotencyKey: idempotencyKey,
    );
  }

  /// Validates that all required fields are complete and non-empty.
  bool get isValid {
    final hasVehicle = vehicleId.trim().isNotEmpty;
    final hasCeremony =
        ceremonyType.trim().isNotEmpty && ceremonialAttire.trim().isNotEmpty;
    final hasLocations =
        city.trim().isNotEmpty &&
        pickupAddress.trim().isNotEmpty &&
        destinationAddress.trim().isNotEmpty;
    final hasContact =
        primaryContactName.trim().length >= 2 &&
        primaryContactPhone.replaceAll(RegExp(r'\D'), '').length >= 10;
    final hasPricing = estimatedTotalPaise > 0 && advanceTokenPaise > 0;
    final hasKey = idempotencyKey.trim().isNotEmpty;

    return hasVehicle &&
        hasCeremony &&
        hasLocations &&
        hasContact &&
        hasPricing &&
        hasKey;
  }
}
