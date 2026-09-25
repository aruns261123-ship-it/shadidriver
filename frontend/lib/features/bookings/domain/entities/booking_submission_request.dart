import 'package:flutter/foundation.dart';
import '../policies/booking_location_rules.dart';
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

  // Service Timing & Route Distance
  final DateTime serviceStartDateTime;
  final DateTime serviceEndDateTime;
  final double? routeDistanceKm;

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
    required this.serviceStartDateTime,
    required this.serviceEndDateTime,
    this.routeDistanceKm,
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

  // --- Convenience Getters ---
  DateTime get eventDate => DateTime(
    serviceStartDateTime.year,
    serviceStartDateTime.month,
    serviceStartDateTime.day,
  );
  int get startTimeHour => serviceStartDateTime.hour;
  int get startTimeMinute => serviceStartDateTime.minute;
  int get durationHours =>
      serviceEndDateTime.difference(serviceStartDateTime).inHours;
  bool get isOvernight =>
      serviceEndDateTime.day != serviceStartDateTime.day || durationHours >= 12;

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
      serviceStartDateTime: draft.serviceStartDateTime,
      serviceEndDateTime: draft.serviceEndDateTime,
      routeDistanceKm: draft.routeDistanceKm,
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

  bool get _hasVehicle => vehicleId.trim().isNotEmpty;

  bool get _hasCeremony =>
      ceremonyType.trim().isNotEmpty && ceremonialAttire.trim().isNotEmpty;

  bool get _hasTiming =>
      serviceEndDateTime.isAfter(serviceStartDateTime) &&
      serviceEndDateTime.difference(serviceStartDateTime).inMinutes >= 60;

  /// Mirrors the backend's own bounds (`@Length(5, 500)` addresses,
  /// `@Length(2, 50)` city) so the app can never send a request the server is
  /// guaranteed to reject with a validation error.
  bool get _hasLocations =>
      BookingLocationRules.isCityValid(city) &&
      BookingLocationRules.isAddressValid(pickupAddress) &&
      BookingLocationRules.isAddressValid(destinationAddress);

  bool get _hasContact =>
      primaryContactName.trim().length >= 2 &&
      primaryContactPhone.replaceAll(RegExp(r'\D'), '').length >= 10;

  bool get _hasPricing => estimatedTotalPaise > 0 && advanceTokenPaise > 0;

  bool get _hasKey => idempotencyKey.trim().isNotEmpty;

  /// Validates that all required fields are complete and non-empty.
  bool get isValid =>
      _hasVehicle &&
      _hasCeremony &&
      _hasTiming &&
      _hasLocations &&
      _hasContact &&
      _hasPricing &&
      _hasKey;

  /// Customer-facing explanation of the first incomplete requirement, used by
  /// the review screen instead of a generic "incomplete draft" message.
  String? get validationMessage {
    if (!_hasVehicle) return 'Select a vehicle to continue.';
    if (!_hasCeremony) return 'Choose the ceremony and ceremonial attire.';
    if (!_hasTiming) {
      return 'Service must run for at least 1 hour and end after it starts.';
    }
    if (cityError != null) return cityError;
    if (pickupAddressError != null) return pickupAddressError;
    if (destinationAddressError != null) return destinationAddressError;
    if (primaryContactName.trim().length < 2) {
      return 'Enter the host contact name (at least 2 characters).';
    }
    if (primaryContactPhone.replaceAll(RegExp(r'\D'), '').length < 10) {
      return 'Enter a valid 10-digit contact phone number.';
    }
    if (!_hasPricing) {
      return 'Pricing could not be confirmed. Please restart the booking.';
    }
    if (!_hasKey) return 'Prepare the booking again before submitting.';
    return null;
  }

  String? get cityError => BookingLocationRules.cityError(city);

  String? get pickupAddressError =>
      BookingLocationRules.addressError(pickupAddress, label: 'pickup address');

  String? get destinationAddressError => BookingLocationRules.addressError(
    destinationAddress,
    label: 'destination address',
  );
}
