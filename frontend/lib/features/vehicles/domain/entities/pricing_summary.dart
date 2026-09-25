/// Business pricing abstraction for luxury mobility services.
/// Supports multiple billing models (hourly, package, distance-based).
class PricingSummary {
  final int basePriceCents;
  final String currencyCode;
  final String billingUnit; // 'HOUR', 'DAY', 'PACKAGE', 'KM'
  final bool isStartingPrice;

  /// TRUE when the backend has not published a tariff for the vehicle yet.
  /// Distinguishes "no price known" from a genuine zero, so the UI can say
  /// "On request" instead of advertising the car at Rs 0.
  final bool isUnavailable;

  const PricingSummary({
    required this.basePriceCents,
    this.currencyCode = 'INR',
    required this.billingUnit,
    this.isStartingPrice = false,
    this.isUnavailable = false,
  });

  /// No server-authoritative tariff is available for this vehicle.
  const PricingSummary.unavailable()
    : basePriceCents = 0,
      currencyCode = 'INR',
      billingUnit = 'DAY',
      isStartingPrice = false,
      isUnavailable = true;

  String get formattedUnit {
    switch (billingUnit) {
      case 'HOUR':
        return '/ hr';
      case 'DAY':
        return '/ day';
      case 'KM':
        return '/ km';
      default:
        return '';
    }
  }
}
