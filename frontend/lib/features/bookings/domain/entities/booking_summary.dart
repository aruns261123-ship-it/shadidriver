/// Core booking summary in the domain layer.
class BookingSummary {
  final String id;
  final String reference;
  final String serviceCategory;
  final String status;
  final DateTime eventStartTime;
  final DateTime eventEndTime;
  final String pickupAddress;
  final String destinationAddress;
  final double? routeDistanceKm;
  final String vehicleName;

  /// Admin-only / legacy rows. The CUSTOMER view never carries a chauffeur
  /// identity — ShadiDriver operations stands behind the service instead —
  /// so this stays empty on customer-facing API responses.
  final String chauffeurName;

  /// Platform assurance copy from the customer-safe DTO
  /// ("Vehicle and chauffeur verified by ShadiDriver", or the allocation
  /// pending variant). The customer learns THAT a chauffeur is arranged,
  /// never WHO it is.
  final String chauffeurVerification;

  final int totalAmountCents;
  final int advanceTokenCents;
  final int version;

  /// Trip-start OTP the host shares with the chauffeur. Real mode: null —
  /// the code is delivered to the host's phone via SMS by the backend and is
  /// never exposed through the API. Mock mode: populated for demo display.
  final String? startOtp;

  const BookingSummary({
    required this.id,
    required this.reference,
    required this.serviceCategory,
    required this.status,
    required this.eventStartTime,
    required this.eventEndTime,
    required this.pickupAddress,
    this.destinationAddress = '',
    this.routeDistanceKm,
    this.vehicleName = '',
    this.chauffeurName = '',
    this.chauffeurVerification = '',
    required this.totalAmountCents,
    required this.advanceTokenCents,
    required this.version,
    this.startOtp,
  });

  /// Service duration in hours.
  int get durationHours => eventEndTime.difference(eventStartTime).inHours;

  /// True when service spans across calendar days.
  bool get isOvernight =>
      eventEndTime.day != eventStartTime.day || durationHours >= 12;

  String get formattedDuration {
    final hrs = durationHours;
    if (isOvernight) {
      return '$hrs hrs (Overnight)';
    }
    return '$hrs hrs';
  }
}
