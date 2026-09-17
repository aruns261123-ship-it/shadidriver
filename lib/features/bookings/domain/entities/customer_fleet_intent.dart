import 'package:flutter/foundation.dart';

/// Customer preference mode for ceremonial fleet selection.
enum CustomerFleetPreference {
  /// Customer specifies guest count and lets the platform assemble any suitable luxury fleet.
  anySuitable,

  /// Customer wants multiple units of a specific preferred vehicle model (e.g. 7 x Toyota Innova).
  preferredModel,

  /// Customer explicitly customizes their mixed fleet breakdown (e.g. 4 x Innova + 3 x Camry + 1 x BMW).
  customFleet,
}

/// Category of fleet composition for a booking.
enum FleetBookingType {
  /// Standard single vehicle booking.
  singleVehicle,

  /// Multiple units of the identical vehicle model.
  sameVehicleMultiple,

  /// Mixed ceremonial fleet composed of multiple distinct models.
  mixedFleet,
}

/// Customer's intent for group or multi-vehicle booking.
@immutable
class CustomerFleetIntent {
  /// Total ceremonial guest / passenger count requiring transport.
  final int passengerCount;

  /// Customer's selection mode.
  final CustomerFleetPreference preference;

  /// Preferred model name when [preference] is [CustomerFleetPreference.preferredModel].
  final String? preferredModel;

  /// Explicit vehicle model to quantity map (e.g. {'Toyota Innova': 4, 'Toyota Camry': 3, 'BMW 5 Series': 1}).
  final Map<String, int> requestedUnits;

  const CustomerFleetIntent({
    required this.passengerCount,
    required this.preference,
    this.preferredModel,
    this.requestedUnits = const {},
  });

  /// Factory for single vehicle booking intent.
  factory CustomerFleetIntent.single({
    required int passengerCount,
    required String model,
  }) {
    return CustomerFleetIntent(
      passengerCount: passengerCount,
      preference: CustomerFleetPreference.preferredModel,
      preferredModel: model,
      requestedUnits: {model: 1},
    );
  }

  /// Factory for multiple units of the same vehicle model (e.g. 40 passengers -> 7 x Innova).
  factory CustomerFleetIntent.sameModelMultiple({
    required int passengerCount,
    required String model,
    required int count,
  }) {
    return CustomerFleetIntent(
      passengerCount: passengerCount,
      preference: CustomerFleetPreference.preferredModel,
      preferredModel: model,
      requestedUnits: {model: count},
    );
  }

  /// Factory for mixed ceremonial fleet (e.g. 4 x Innova, 3 x Camry, 1 x BMW).
  factory CustomerFleetIntent.mixed({
    required int passengerCount,
    required Map<String, int> units,
  }) {
    return CustomerFleetIntent(
      passengerCount: passengerCount,
      preference: CustomerFleetPreference.customFleet,
      requestedUnits: units,
    );
  }

  /// Factory for any suitable luxury vehicle fleet to accommodate [passengerCount].
  factory CustomerFleetIntent.anySuitable({
    required int passengerCount,
  }) {
    return CustomerFleetIntent(
      passengerCount: passengerCount,
      preference: CustomerFleetPreference.anySuitable,
    );
  }

  /// Resolves the booking type based on units and preference.
  FleetBookingType get bookingType {
    final totalUnits = requestedUnits.values.fold<int>(0, (sum, count) => sum + count);
    if (totalUnits <= 1 && requestedUnits.length <= 1 && preference != CustomerFleetPreference.customFleet) {
      return FleetBookingType.singleVehicle;
    }
    if (requestedUnits.length == 1) {
      return FleetBookingType.sameVehicleMultiple;
    }
    return FleetBookingType.mixedFleet;
  }

  /// Total number of requested vehicle units across all models.
  int get totalRequestedUnits {
    if (requestedUnits.isEmpty) return 1;
    return requestedUnits.values.fold<int>(0, (sum, count) => sum + count);
  }
}
