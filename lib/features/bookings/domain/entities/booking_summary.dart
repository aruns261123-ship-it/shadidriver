/// Core booking summary in the domain layer.
class BookingSummary {
  final String id;
  final String reference;
  final String serviceCategory;
  final String status;
  final DateTime eventStartTime;
  final DateTime eventEndTime;
  final String pickupAddress;
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
    required this.totalAmountCents,
    required this.advanceTokenCents,
    required this.version,
  });
}
