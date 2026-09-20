import '../domain/policies/booking_pricing_policy.dart';

/// Mock/development implementation of [AdvancePaymentPolicy].
///
/// NOTE: Commercial advance rates are NOT finalized and must be supplied by
/// server-authoritative configuration in production. This implementation is
/// for local development and demonstration only.
class DevelopmentAdvancePaymentPolicy implements AdvancePaymentPolicy {
  /// Configurable advance percentage (e.g. 0.20 for development demonstration).
  final double advancePercentage;

  @override
  final String advanceTokenLabel;

  const DevelopmentAdvancePaymentPolicy({
    this.advancePercentage = 0.20,
    this.advanceTokenLabel = 'Advance Token',
  });

  @override
  int calculateAdvanceTokenPaise(int totalPaise) {
    return (totalPaise * advancePercentage).round();
  }
}

/// Mock/development implementation of [BookingPricingPolicy].
///
/// NOTE: Duration multipliers and overtime rates are configurable for testing
/// and demonstration, and must be server-authoritative in production.
class DevelopmentBookingPricingPolicy implements BookingPricingPolicy {
  @override
  final AdvancePaymentPolicy advancePaymentPolicy;

  /// Standard ceremony package duration in hours.
  final int standardDurationHours;

  /// Multiplier for short packages (<= 4 hours).
  final double shortPackageMultiplier;

  /// Hourly overtime rate as a fraction of base price for hours exceeding [standardDurationHours].
  final double overtimeRatePerHour;

  const DevelopmentBookingPricingPolicy({
    this.advancePaymentPolicy = const DevelopmentAdvancePaymentPolicy(),
    this.standardDurationHours = 8,
    this.shortPackageMultiplier = 0.70,
    this.overtimeRatePerHour = 0.15,
  });

  @override
  BookingPricingCalculation calculatePricing({
    required int basePricePaise,
    required int durationHours,
  }) {
    final int estimatedTotal;
    if (durationHours <= 4) {
      estimatedTotal = (basePricePaise * shortPackageMultiplier).round();
    } else if (durationHours <= standardDurationHours) {
      estimatedTotal = basePricePaise;
    } else {
      final extraHours = durationHours - standardDurationHours;
      final extraRate = (basePricePaise * overtimeRatePerHour).round();
      estimatedTotal = basePricePaise + (extraHours * extraRate);
    }

    final advanceToken = advancePaymentPolicy.calculateAdvanceTokenPaise(
      estimatedTotal,
    );

    return BookingPricingCalculation(
      basePricePaise: basePricePaise,
      estimatedTotalPaise: estimatedTotal,
      advanceTokenPaise: advanceToken,
      advanceTokenLabel: advancePaymentPolicy.advanceTokenLabel,
    );
  }

  /// Net chauffeur payout share (provisional 80% net of platform fee).
  final double driverPayoutShare = 0.80;

  @override
  int calculateDriverEarningsPaise(int totalPaise) {
    return (totalPaise * driverPayoutShare).round();
  }
}
