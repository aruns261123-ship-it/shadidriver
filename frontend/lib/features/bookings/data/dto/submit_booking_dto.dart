import '../../domain/entities/booking_submission_request.dart';

/// Wire representation of `POST /api/v1/bookings`.
///
/// **Source of truth:** the backend DTO in
/// `backend/src/bookings/bookings.controller.ts` (`class SubmitBookingDto`).
/// That DTO is validated with `whitelist: true, forbidNonWhitelisted: true`, so
/// the field set below is exact: any extra key is a `400 VALIDATION_FAILED`
/// (`property x should not exist`) and any missing required key is a `400`
/// naming that property.
///
/// This class is the ONLY place that knows backend JSON names. Domain and
/// presentation code keep their own vocabulary, and a future rename on either
/// side is a change here rather than a silent contract break.
///
/// Canonical request (camelCase, flat):
/// ```
/// serviceCategoryId, vehicleTypeId, ceremonyType, ceremonialAttire,
/// specialInstructions?, serviceStartTime, serviceEndTime, city,
/// pickupAddress, destinationAddress, venueName?, routeDistanceKm?,
/// primaryContactName, primaryContactPhone, passengerCount, selectedAddonIds?
/// ```
///
/// The idempotency token travels in the `Idempotency-Key` HTTP header — it is
/// deliberately NOT a body field (`SubmitBookingDto` would reject it).
class SubmitBookingDto {
  /// Every body field the backend declares, as documented above. Tests assert
  /// the serialized payload against this set so drift fails loudly.
  static const Set<String> contractFields = {
    'serviceCategoryId',
    'vehicleTypeId',
    'ceremonyType',
    'ceremonialAttire',
    'specialInstructions',
    'serviceStartTime',
    'serviceEndTime',
    'city',
    'pickupAddress',
    'destinationAddress',
    'venueName',
    'routeDistanceKm',
    'primaryContactName',
    'primaryContactPhone',
    'passengerCount',
    'selectedAddonIds',
  };

  /// Fields the backend requires (no `@IsOptional()`).
  static const Set<String> requiredContractFields = {
    'serviceCategoryId',
    'vehicleTypeId',
    'ceremonyType',
    'ceremonialAttire',
    'serviceStartTime',
    'serviceEndTime',
    'city',
    'pickupAddress',
    'destinationAddress',
    'primaryContactName',
    'primaryContactPhone',
    'passengerCount',
  };

  final String serviceCategoryId;
  final String vehicleTypeId;
  final String ceremonyType;
  final String ceremonialAttire;
  final String specialInstructions;
  final DateTime serviceStartTime;
  final DateTime serviceEndTime;
  final String city;
  final String pickupAddress;
  final String destinationAddress;
  final String venueName;
  final double? routeDistanceKm;
  final String primaryContactName;
  final String primaryContactPhone;
  final int passengerCount;
  final List<String> selectedAddonIds;

  const SubmitBookingDto({
    required this.serviceCategoryId,
    required this.vehicleTypeId,
    required this.ceremonyType,
    required this.ceremonialAttire,
    required this.serviceStartTime,
    required this.serviceEndTime,
    required this.city,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.primaryContactName,
    required this.primaryContactPhone,
    required this.passengerCount,
    this.specialInstructions = '',
    this.venueName = '',
    this.routeDistanceKm,
    this.selectedAddonIds = const [],
  });

  /// Explicitly maps the domain request onto the canonical wire contract.
  ///
  /// [serviceCategoryId] is resolved by [ServiceCategoryPolicy] before this
  /// point because it is a domain decision, not a serialization one.
  factory SubmitBookingDto.fromDomain(
    BookingSubmissionRequest request, {
    required String serviceCategoryId,
  }) {
    return SubmitBookingDto(
      serviceCategoryId: serviceCategoryId,
      // Domain `vehicleId` identifies the chosen fleet asset. The backend
      // accepts either a vehicle UUID or a vehicle-type id here; it resolves
      // whichever it receives (QuotesService.createQuote).
      vehicleTypeId: request.vehicleId.trim().isNotEmpty
          ? request.vehicleId.trim()
          : request.vehicleClass.trim(),
      ceremonyType: request.ceremonyType.trim(),
      ceremonialAttire: request.ceremonialAttire.trim(),
      specialInstructions: request.specialInstructions.trim(),
      serviceStartTime: request.serviceStartDateTime.toUtc(),
      serviceEndTime: request.serviceEndDateTime.toUtc(),
      city: request.city.trim(),
      pickupAddress: request.pickupAddress.trim(),
      destinationAddress: request.destinationAddress.trim(),
      venueName: request.venueName.trim(),
      routeDistanceKm: request.routeDistanceKm,
      primaryContactName: request.primaryContactName.trim(),
      primaryContactPhone: request.primaryContactPhone.trim(),
      passengerCount: request.passengerCount,
    );
  }

  /// Mirrors the constraints the backend declares on `SubmitBookingDto`
  /// (`@Length(...)`, `@Min/@Max`, `@IsNumber`) and returns the first
  /// violation as a customer-facing sentence, or null when the payload would be
  /// accepted.
  ///
  /// This exists so the app never spends a round trip on a request the server
  /// is guaranteed to reject — and so the customer is told which field to fix
  /// instead of being shown a server validation error after review.
  String? firstContractViolation() {
    return _textRule('service category', serviceCategoryId, 2, 50) ??
        _textRule('vehicle', vehicleTypeId, 2, 50) ??
        _textRule('ceremony type', ceremonyType, 2, 60) ??
        _textRule('ceremonial attire', ceremonialAttire, 2, 100) ??
        _textRule('city', city, 2, 50) ??
        _textRule('pickup address', pickupAddress, 5, 500) ??
        _textRule('destination address', destinationAddress, 5, 500) ??
        _textRule('contact name', primaryContactName, 2, 120) ??
        _textRule('contact phone number', primaryContactPhone, 8, 20) ??
        (routeDistanceKm != null && routeDistanceKm! < 0
            ? 'Route distance cannot be negative.'
            : null) ??
        (passengerCount < 1 || passengerCount > 60
            ? 'Passenger count must be between 1 and 60.'
            : null);
  }

  static String? _textRule(String label, String value, int min, int max) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter the $label.';
    if (trimmed.length < min) {
      return '${_capitalize(label)} must be at least $min characters.';
    }
    if (trimmed.length > max) {
      return '${_capitalize(label)} must be $max characters or fewer.';
    }
    return null;
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  /// Optional properties are omitted rather than sent empty so the payload
  /// stays minimal and every present key is meaningful.
  Map<String, dynamic> toJson() => {
    'serviceCategoryId': serviceCategoryId,
    'vehicleTypeId': vehicleTypeId,
    'ceremonyType': ceremonyType,
    'ceremonialAttire': ceremonialAttire,
    if (specialInstructions.isNotEmpty) 'specialInstructions': specialInstructions,
    'serviceStartTime': serviceStartTime.toIso8601String(),
    'serviceEndTime': serviceEndTime.toIso8601String(),
    'city': city,
    'pickupAddress': pickupAddress,
    'destinationAddress': destinationAddress,
    if (venueName.isNotEmpty) 'venueName': venueName,
    if (routeDistanceKm != null) 'routeDistanceKm': routeDistanceKm,
    'primaryContactName': primaryContactName,
    'primaryContactPhone': primaryContactPhone,
    'passengerCount': passengerCount,
    if (selectedAddonIds.isNotEmpty) 'selectedAddonIds': selectedAddonIds,
  };
}
