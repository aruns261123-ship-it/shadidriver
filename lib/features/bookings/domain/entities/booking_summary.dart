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
