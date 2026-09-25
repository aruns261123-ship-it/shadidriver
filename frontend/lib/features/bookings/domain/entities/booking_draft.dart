import 'package:flutter/material.dart';
import '../policies/booking_location_rules.dart';

/// Status of a customer booking draft during Milestone 4A.
enum BookingDraftStatus {
  /// User is filling in details.
  draft,

  /// Draft has been validated and persisted locally/in-memory.
  saved,
}

/// Immutable domain model representing a customer booking draft and event details.
///
/// Strictly adheres to the Milestone 4A & Phase 1 specifications:
/// - Event / Ceremony
/// - Explicit Service Start (Date + Time) & End (Date + Time)
/// - Calculated Duration & Overnight Support
/// - Route Distance (km) via abstraction
/// - Pickup / Destination
/// - Passenger Details
///
/// Monetary values are explicit and supplied by a policy/pricing abstraction.
/// The domain entity does NOT calculate or embed any commercial percentages,
/// commission rates, cancellation terms, or token deposit policies.
@immutable
class BookingDraft {
  final String id;
  final String vehicleId;
  final String vehicleName;
  final String vehicleClass;

  /// Always empty for a customer selection: ShadiDriver operations assigns the
  /// chauffeur internally after the request is reviewed. Retained so existing
  /// serialization keeps a stable shape; never populated from a vehicle page.
  final String chauffeurId;

  // 1. Event & Ceremony Details
  final String ceremonyType;
  final String ceremonialAttire;
  final String specialInstructions;

  // 2. Service Timing & Duration
  final DateTime serviceStartDateTime;
  final DateTime serviceEndDateTime;
  final double? routeDistanceKm;

  // 3. Pickup & Destination
  final String city;
  final String pickupAddress;
  final String destinationAddress;
  final String venueName;
  final String landmark;

  // 4. Passenger Details
  final String primaryContactName;
  final String primaryContactPhone;
  final String? alternateContactPhone;
  final int passengerCount;

  // Pricing & Metadata (explicit monetary values supplied by pricing policy)
  final List<String> selectedAddonIds;
  final int basePricePaise;
  final int estimatedTotalPaise;
  final int advanceTokenPaise;
  final String advanceTokenLabel;
  final DateTime createdAt;
  final BookingDraftStatus status;

  const BookingDraft({
    required this.id,
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleClass,
    this.chauffeurId = '',
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
    this.passengerCount = 2,
    this.selectedAddonIds = const [],
    required this.basePricePaise,
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.advanceTokenLabel = 'Advance Token',
    required this.createdAt,
    this.status = BookingDraftStatus.draft,
  });

  /// Factory creating an initial empty draft for a specific vehicle with explicit pricing values.
  factory BookingDraft.initial({
    required String vehicleId,
    required String vehicleName,
    required String vehicleClass,
    String chauffeurId = '',
    required int basePricePaise,
    required int estimatedTotalPaise,
    required int advanceTokenPaise,
    String advanceTokenLabel = 'Advance Token',
    String ceremonyType = 'Baraat',
    String ceremonialAttire = 'Royal Bandhgala & Gold Safa',
    DateTime? serviceStartDateTime,
    DateTime? serviceEndDateTime,
    DateTime? eventDate,
    TimeOfDay? startTime,
    int durationHours = 8,
    double? routeDistanceKm,
    String city = 'Delhi NCR',
    int passengerCount = 2,
  }) {
    final now = DateTime.now();
    final effectiveStart =
        serviceStartDateTime ??
        (eventDate != null
            ? DateTime(
                eventDate.year,
                eventDate.month,
                eventDate.day,
                startTime?.hour ?? 16,
                startTime?.minute ?? 0,
              )
            : DateTime(now.year, now.month, now.day + 7, 16, 0));
    final effectiveEnd =
        serviceEndDateTime ??
        effectiveStart.add(Duration(hours: durationHours));

    return BookingDraft(
      id: 'draft_${vehicleId}_${now.millisecondsSinceEpoch}',
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      vehicleClass: vehicleClass,
      chauffeurId: chauffeurId,
      ceremonyType: ceremonyType,
      ceremonialAttire: ceremonialAttire,
      specialInstructions: '',
      serviceStartDateTime: effectiveStart,
      serviceEndDateTime: effectiveEnd,
      routeDistanceKm: routeDistanceKm,
      city: city,
      pickupAddress: '',
      destinationAddress: '',
      venueName: '',
      landmark: '',
      primaryContactName: '',
      primaryContactPhone: '',
      alternateContactPhone: null,
      passengerCount: passengerCount,
      selectedAddonIds: const [],
      basePricePaise: basePricePaise,
      estimatedTotalPaise: estimatedTotalPaise,
      advanceTokenPaise: advanceTokenPaise,
      advanceTokenLabel: advanceTokenLabel,
      createdAt: now,
      status: BookingDraftStatus.draft,
    );
  }

  // --- Convenience & Backwards-Compatible Getters ---
  DateTime get eventDate => DateTime(
    serviceStartDateTime.year,
    serviceStartDateTime.month,
    serviceStartDateTime.day,
  );
  TimeOfDay get startTime => TimeOfDay(
    hour: serviceStartDateTime.hour,
    minute: serviceStartDateTime.minute,
  );
  TimeOfDay get endTime => TimeOfDay(
    hour: serviceEndDateTime.hour,
    minute: serviceEndDateTime.minute,
  );
  DateTime get startDateTime => serviceStartDateTime;
  DateTime get endDateTime => serviceEndDateTime;

  /// Calculated service duration in hours.
  int get durationHours =>
      serviceEndDateTime.difference(serviceStartDateTime).inHours;

  /// Calculated service duration in minutes.
  int get durationMinutes =>
      serviceEndDateTime.difference(serviceStartDateTime).inMinutes;

  /// True when service spans across calendar days (e.g. 8:00 PM to 7:00 AM next day).
  bool get isOvernight {
    if (serviceEndDateTime.year != serviceStartDateTime.year ||
        serviceEndDateTime.month != serviceStartDateTime.month ||
        serviceEndDateTime.day != serviceStartDateTime.day) {
      return true;
    }
    return durationHours >= 12;
  }

  /// Formatted duration label (e.g. "11 hours (Overnight)" or "8 hours").
  String get formattedDuration {
    final hrs = durationHours;
    if (isOvernight) {
      return '$hrs hrs (Overnight)';
    }
    return '$hrs hrs';
  }

  /// Validates Section 1: Event & Ceremony
  bool get isCeremonyValid =>
      ceremonyType.trim().isNotEmpty && ceremonialAttire.trim().isNotEmpty;

  /// Validates Section 2: Date & Time
  /// Invariants:
  /// - End must be strictly after start
  /// - Duration must be positive (minimum 1 hour)
  /// - Start must not be in the past (tolerates today)
  bool get isDateTimeValid {
    if (!serviceEndDateTime.isAfter(serviceStartDateTime)) return false;
    final diff = serviceEndDateTime.difference(serviceStartDateTime);
    if (diff.inMinutes < 60) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return serviceStartDateTime.isAfter(yesterday);
  }

  /// Validates Section 3: Pickup & Destination against the backend's own
  /// bounds (`@Length(5, 500)` on addresses, `@Length(2, 50)` on city) so a
  /// draft the server would reject can never be submitted.
  bool get isLocationsValid =>
      BookingLocationRules.isCityValid(city) &&
      BookingLocationRules.isAddressValid(pickupAddress) &&
      BookingLocationRules.isAddressValid(destinationAddress);

  /// The first location problem to show the customer, or null when Section 3
  /// is complete. Drives the inline field errors in the booking form.
  String? get pickupAddressError =>
      BookingLocationRules.addressError(pickupAddress, label: 'pickup address');

  String? get destinationAddressError => BookingLocationRules.addressError(
    destinationAddress,
    label: 'destination address',
  );

  String? get cityError => BookingLocationRules.cityError(city);

  String? get locationValidationMessage =>
      cityError ?? pickupAddressError ?? destinationAddressError;

  /// Validates Section 4: Passenger Details
  bool get isPassengerDetailsValid {
    final nameValid = primaryContactName.trim().length >= 2;
    final digits = primaryContactPhone.replaceAll(RegExp(r'\D'), '');
    final phoneValid =
        digits.length == 10 || (digits.length == 12 && digits.startsWith('91'));
    final passengersValid = passengerCount >= 1;
    return nameValid && phoneValid && passengersValid;
  }

  /// True when all required fields across all 4 sections are complete and valid.
  bool get isComplete =>
      isCeremonyValid &&
      isDateTimeValid &&
      isLocationsValid &&
      isPassengerDetailsValid;

  BookingDraft copyWith({
    String? id,
    String? vehicleId,
    String? vehicleName,
    String? vehicleClass,
    String? chauffeurId,
    String? ceremonyType,
    String? ceremonialAttire,
    String? specialInstructions,
    DateTime? serviceStartDateTime,
    DateTime? serviceEndDateTime,
    DateTime? eventDate,
    TimeOfDay? startTime,
    int? durationHours,
    double? routeDistanceKm,
    String? city,
    String? pickupAddress,
    String? destinationAddress,
    String? venueName,
    String? landmark,
    String? primaryContactName,
    String? primaryContactPhone,
    String? alternateContactPhone,
    int? passengerCount,
    List<String>? selectedAddonIds,
    int? basePricePaise,
    int? estimatedTotalPaise,
    int? advanceTokenPaise,
    String? advanceTokenLabel,
    DateTime? createdAt,
    BookingDraftStatus? status,
  }) {
    DateTime effectiveStart = serviceStartDateTime ?? this.serviceStartDateTime;
    if (serviceStartDateTime == null &&
        (eventDate != null || startTime != null)) {
      final baseDate = eventDate ?? this.eventDate;
      final baseTime = startTime ?? this.startTime;
      effectiveStart = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        baseTime.hour,
        baseTime.minute,
      );
    }

    DateTime effectiveEnd = serviceEndDateTime ?? this.serviceEndDateTime;
    if (serviceEndDateTime == null && durationHours != null) {
      effectiveEnd = effectiveStart.add(Duration(hours: durationHours));
    }

    return BookingDraft(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      ceremonyType: ceremonyType ?? this.ceremonyType,
      ceremonialAttire: ceremonialAttire ?? this.ceremonialAttire,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      serviceStartDateTime: effectiveStart,
      serviceEndDateTime: effectiveEnd,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      city: city ?? this.city,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      venueName: venueName ?? this.venueName,
      landmark: landmark ?? this.landmark,
      primaryContactName: primaryContactName ?? this.primaryContactName,
      primaryContactPhone: primaryContactPhone ?? this.primaryContactPhone,
      alternateContactPhone:
          alternateContactPhone ?? this.alternateContactPhone,
      passengerCount: passengerCount ?? this.passengerCount,
      selectedAddonIds: selectedAddonIds ?? this.selectedAddonIds,
      basePricePaise: basePricePaise ?? this.basePricePaise,
      estimatedTotalPaise: estimatedTotalPaise ?? this.estimatedTotalPaise,
      advanceTokenPaise: advanceTokenPaise ?? this.advanceTokenPaise,
      advanceTokenLabel: advanceTokenLabel ?? this.advanceTokenLabel,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookingDraft &&
          other.id == id &&
          other.vehicleId == vehicleId &&
          other.vehicleName == vehicleName &&
          other.vehicleClass == vehicleClass &&
          other.chauffeurId == chauffeurId &&
          other.ceremonyType == ceremonyType &&
          other.ceremonialAttire == ceremonialAttire &&
          other.specialInstructions == specialInstructions &&
          other.serviceStartDateTime == serviceStartDateTime &&
          other.serviceEndDateTime == serviceEndDateTime &&
          other.routeDistanceKm == routeDistanceKm &&
          other.city == city &&
          other.pickupAddress == pickupAddress &&
          other.destinationAddress == destinationAddress &&
          other.venueName == venueName &&
          other.landmark == landmark &&
          other.primaryContactName == primaryContactName &&
          other.primaryContactPhone == primaryContactPhone &&
          other.alternateContactPhone == alternateContactPhone &&
          other.passengerCount == passengerCount &&
          other.basePricePaise == basePricePaise &&
          other.estimatedTotalPaise == estimatedTotalPaise &&
          other.advanceTokenPaise == advanceTokenPaise &&
          other.advanceTokenLabel == advanceTokenLabel &&
          other.status == status);

  @override
  int get hashCode => Object.hashAll([
    id,
    vehicleId,
    vehicleName,
    vehicleClass,
    chauffeurId,
    ceremonyType,
    ceremonialAttire,
    specialInstructions,
    serviceStartDateTime,
    serviceEndDateTime,
    routeDistanceKm,
    city,
    pickupAddress,
    destinationAddress,
    venueName,
    landmark,
    primaryContactName,
    primaryContactPhone,
    alternateContactPhone,
    passengerCount,
    basePricePaise,
    estimatedTotalPaise,
    advanceTokenPaise,
    advanceTokenLabel,
    status,
  ]);
}
