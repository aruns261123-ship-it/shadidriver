/// Business pricing abstraction for luxury mobility services.
/// Supports multiple billing models (hourly, package, distance-based).
class PricingSummary {
  final int basePriceCents;
  final String currencyCode;
  final String billingUnit; // 'HOUR', 'DAY', 'PACKAGE', 'KM'
  final bool isStartingPrice;

  const PricingSummary({
    required this.basePriceCents,
    this.currencyCode = 'INR',
    required this.billingUnit,
    this.isStartingPrice = false,
  });

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
