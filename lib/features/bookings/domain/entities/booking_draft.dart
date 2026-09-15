import 'package:flutter/material.dart';

/// Status of a customer booking draft during Milestone 4A.
enum BookingDraftStatus {
  /// User is filling in details.
  draft,

  /// Draft has been validated and persisted locally/in-memory.
  saved,
}

/// Immutable domain model representing a customer booking draft and event details.
///
/// Strictly adheres to the Milestone 4A specification:
/// - Event / Ceremony
/// - Date / Time
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
  final String chauffeurId;

  // 1. Event & Ceremony Details
  final String ceremonyType;
  final String ceremonialAttire;
  final String specialInstructions;

  // 2. Date & Time
  final DateTime eventDate;
  final TimeOfDay startTime;
  final int durationHours;

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
    required this.chauffeurId,
    required this.ceremonyType,
    required this.ceremonialAttire,
    this.specialInstructions = '',
    required this.eventDate,
    required this.startTime,
    this.durationHours = 8,
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
  ///
  /// NOTE: Monetary values ([basePricePaise], [estimatedTotalPaise], [advanceTokenPaise])
  /// are supplied directly by an external pricing/policy abstraction, not computed here.
  factory BookingDraft.initial({
    required String vehicleId,
    required String vehicleName,
    required String vehicleClass,
    required String chauffeurId,
    required int basePricePaise,
    required int estimatedTotalPaise,
    required int advanceTokenPaise,
    String advanceTokenLabel = 'Advance Token',
    String ceremonyType = 'Baraat',
    String ceremonialAttire = 'Royal Bandhgala & Gold Safa',
    int durationHours = 8,
    String city = 'Delhi NCR',
    int passengerCount = 2,
    DateTime? eventDate,
    TimeOfDay? startTime,
  }) {
    final now = DateTime.now();
    final defaultDate = eventDate ?? DateTime(now.year, now.month, now.day + 7);

    return BookingDraft(
      id: 'draft_${vehicleId}_${now.millisecondsSinceEpoch}',
      vehicleId: vehicleId,
      vehicleName: vehicleName,
      vehicleClass: vehicleClass,
      chauffeurId: chauffeurId,
      ceremonyType: ceremonyType,
      ceremonialAttire: ceremonialAttire,
      specialInstructions: '',
      eventDate: defaultDate,
      startTime: startTime ?? const TimeOfDay(hour: 16, minute: 0), // 4:00 PM
      durationHours: durationHours,
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

  /// Calculates start DateTime.
  DateTime get startDateTime => DateTime(
    eventDate.year,
    eventDate.month,
    eventDate.day,
    startTime.hour,
    startTime.minute,
  );

  /// Calculates end DateTime based on start time and duration.
  DateTime get endDateTime => startDateTime.add(Duration(hours: durationHours));

  /// Validates Section 1: Event & Ceremony
  bool get isCeremonyValid =>
      ceremonyType.trim().isNotEmpty && ceremonialAttire.trim().isNotEmpty;

  /// Validates Section 2: Date & Time
  bool get isDateTimeValid =>
      durationHours >= 2 &&
      eventDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));

  /// Validates Section 3: Pickup & Destination
  bool get isLocationsValid =>
      city.trim().isNotEmpty &&
      pickupAddress.trim().isNotEmpty &&
      destinationAddress.trim().isNotEmpty;

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
    DateTime? eventDate,
    TimeOfDay? startTime,
    int? durationHours,
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
    return BookingDraft(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleClass: vehicleClass ?? this.vehicleClass,
      chauffeurId: chauffeurId ?? this.chauffeurId,
      ceremonyType: ceremonyType ?? this.ceremonyType,
      ceremonialAttire: ceremonialAttire ?? this.ceremonialAttire,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      durationHours: durationHours ?? this.durationHours,
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
          other.ceremonyType == ceremonyType &&
          other.eventDate == eventDate &&
          other.durationHours == durationHours &&
          other.pickupAddress == pickupAddress &&
          other.destinationAddress == destinationAddress &&
          other.primaryContactName == primaryContactName &&
          other.primaryContactPhone == primaryContactPhone &&
          other.basePricePaise == basePricePaise &&
          other.estimatedTotalPaise == estimatedTotalPaise &&
          other.advanceTokenPaise == advanceTokenPaise &&
          other.advanceTokenLabel == advanceTokenLabel &&
          other.status == status);

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    ceremonyType,
    eventDate,
    durationHours,
    pickupAddress,
    destinationAddress,
    primaryContactName,
    basePricePaise,
    estimatedTotalPaise,
    advanceTokenPaise,
    advanceTokenLabel,
    status,
  );
}
