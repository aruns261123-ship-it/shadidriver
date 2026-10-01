import 'package:flutter/foundation.dart';

import '../../../search/domain/entities/trip_type.dart';

/// Intent captured by the search flow and carried into booking draft
/// creation, so the customer never re-enters values already known
/// (Search → Results → Draft → Review handoff).
///
/// Kept in the bookings feature so booking code has no dependency on the
/// search feature; the provider layer maps the search query onto this.
@immutable
class SearchHandoff {
  /// Destination / venue the customer searched with.
  final String? destination;

  /// Pickup location as entered in search (usually city-level).
  final String? pickupLocation;

  /// Event date selected during search.
  final DateTime? eventDate;

  /// Occasion / ceremony type selected during search (e.g. 'Baraat').
  final String? occasion;

  /// Passenger count from the search criteria.
  final int? passengerCount;

  /// Trip direction chosen during search (ONE_WAY | ROUND_TRIP). Carried into
  /// the booking draft and echoed to the server, which prices it.
  final TripType tripType;

  const SearchHandoff({
    this.destination,
    this.pickupLocation,
    this.eventDate,
    this.occasion,
    this.passengerCount,
    this.tripType = TripType.oneWay,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchHandoff &&
          other.destination == destination &&
          other.pickupLocation == pickupLocation &&
          other.eventDate == eventDate &&
          other.occasion == occasion &&
          other.passengerCount == passengerCount &&
          other.tripType == tripType);

  @override
  int get hashCode =>
      Object.hash(destination, pickupLocation, eventDate, occasion, passengerCount, tripType);

  /// True when at least one field carries intent worth prefilling.
  bool get hasAny =>
      (destination != null && destination!.trim().isNotEmpty) ||
      (pickupLocation != null && pickupLocation!.trim().isNotEmpty) ||
      eventDate != null ||
      (occasion != null && occasion!.trim().isNotEmpty) ||
      (passengerCount != null && passengerCount! > 0) ||
      tripType != TripType.oneWay;
}
