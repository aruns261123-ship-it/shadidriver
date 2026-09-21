import 'package:flutter/foundation.dart';

/// Alternative suggestion when requested fleet inventory is partially or fully unavailable.
@immutable
class FleetAlternativeSuggestion {
  /// Suggested replacement or supplementary vehicle model.
  final String modelName;

  /// Quantity suggested.
  final int suggestedCount;

  /// Seating capacity per unit.
  final int capacityPerUnit;

  /// Human-readable explanation of why this alternative is suggested.
  final String rationale;

  const FleetAlternativeSuggestion({
    required this.modelName,
    required this.suggestedCount,
    required this.capacityPerUnit,
    required this.rationale,
  });

  /// Total passenger capacity provided by this suggestion.
  int get totalCapacity => suggestedCount * capacityPerUnit;
}

/// Result of evaluating fleet availability for a multi-vehicle ceremonial booking intent.
///
/// Invariant: Does NOT silently substitute vehicles. If requested units exceed availability,
/// the shortfall is explicitly documented alongside alternative suggestions.
@immutable
class FleetAvailabilityResult {
  /// True if 100% of the requested fleet is available.
  final bool isFullyAvailable;

  /// The vehicle model requested, if checking a single preferred model.
  final String? requestedModel;

  /// Number of units requested.
  final int requestedCount;

  /// Number of units confirmed available.
  final int availableCount;

  /// Units short of the customer's request.
  final int shortfall;

  /// Explicit alternative vehicle suggestions when shortfall > 0.
  final List<FleetAlternativeSuggestion> alternativeSuggestions;

  /// Informational status message for UI presentation.
  final String message;

  const FleetAvailabilityResult({
    required this.isFullyAvailable,
    this.requestedModel,
    required this.requestedCount,
    required this.availableCount,
    required this.shortfall,
    this.alternativeSuggestions = const [],
    required this.message,
  });

  /// Factory for a fully available fleet match.
  factory FleetAvailabilityResult.available({
    String? model,
    required int count,
  }) {
    return FleetAvailabilityResult(
      isFullyAvailable: true,
      requestedModel: model,
      requestedCount: count,
      availableCount: count,
      shortfall: 0,
      message: 'All $count requested units are available for the ceremony.',
    );
  }

  /// Factory for a partial availability result requiring explicit alternatives.
  factory FleetAvailabilityResult.partial({
    required String model,
    required int requestedCount,
    required int availableCount,
    required List<FleetAlternativeSuggestion> alternativeSuggestions,
  }) {
    final shortfall = requestedCount - availableCount;
    return FleetAvailabilityResult(
      isFullyAvailable: false,
      requestedModel: model,
      requestedCount: requestedCount,
      availableCount: availableCount,
      shortfall: shortfall,
      alternativeSuggestions: alternativeSuggestions,
      message:
          'Only $availableCount of $requestedCount $model units available. $shortfall additional unit(s) required.',
    );
  }
}
