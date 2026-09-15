import 'package:flutter/foundation.dart';

/// Explicit calculation result produced by a [BookingPricingPolicy].
@immutable
class BookingPricingCalculation {
  /// Base price in paise for the vehicle/service.
  final int basePricePaise;

  /// Estimated total fare in paise for the requested duration.
  final int estimatedTotalPaise;

  /// Advance token amount in paise required to secure reservation.
  final int advanceTokenPaise;

  /// Human-readable label describing the advance token tier.
  final String advanceTokenLabel;

  const BookingPricingCalculation({
    required this.basePricePaise,
    required this.estimatedTotalPaise,
    required this.advanceTokenPaise,
    this.advanceTokenLabel = 'Advance Token',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookingPricingCalculation &&
          other.basePricePaise == basePricePaise &&
          other.estimatedTotalPaise == estimatedTotalPaise &&
          other.advanceTokenPaise == advanceTokenPaise &&
          other.advanceTokenLabel == advanceTokenLabel);

  @override
  int get hashCode => Object.hash(
    basePricePaise,
    estimatedTotalPaise,
    advanceTokenPaise,
    advanceTokenLabel,
  );
}

/// Abstract contract for advance payment policies.
///
/// NOTE: Commercial policies (such as token percentage, escrow splits,
/// and cancellation fee bounds) are provisional and subject to business finalization.
abstract interface class AdvancePaymentPolicy {
  /// Computes the advance token in paise given the estimated total amount.
  int calculateAdvanceTokenPaise(int totalPaise);

  /// Informational label for display in client UI.
  String get advanceTokenLabel;
}

/// Abstract contract for booking pricing calculation.
///
/// Implementations handle duration tiering, overtime charges, and advance token calculations.
abstract interface class BookingPricingPolicy {
  /// Returns the pricing breakdown for a booking draft.
  BookingPricingCalculation calculatePricing({
    required int basePricePaise,
    required int durationHours,
  });

  /// Associated advance payment policy.
  AdvancePaymentPolicy get advancePaymentPolicy;
}
