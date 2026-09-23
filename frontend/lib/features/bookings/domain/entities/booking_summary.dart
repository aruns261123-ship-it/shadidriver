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
  final String chauffeurName;
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
