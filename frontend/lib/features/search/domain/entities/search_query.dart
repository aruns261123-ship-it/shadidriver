import 'package:flutter/foundation.dart';

/// Immutable domain model representing a comprehensive vehicle search request.
@immutable
class VehicleSearchQuery {
  final String? pickupLocation;
  final String? destination;
  final DateTime? eventDate;
  final String? eventTime;
  final String? occasionId;
  final int? passengerCount;

  // Filters
  final List<String>? vehicleCategories;
  final int? minModelYear;
  final int? maxModelYear;
  final int? minPriceCents;
  final int? maxPriceCents;
  final List<int>? seatingCapacities;
  final String? transmission; // 'AUTOMATIC', 'MANUAL'
  final double? minRating;
  final double? maxDistanceKm;
  final bool verifiedChauffeurOnly;
  final bool verifiedVehicleOnly;
  final bool availableNow;
  final List<String>? amenities;
  final List<String>? addonIds;

  const VehicleSearchQuery({
    this.pickupLocation,
    this.destination,
    this.eventDate,
    this.eventTime,
    this.occasionId,
    this.passengerCount,
    this.vehicleCategories,
    this.minModelYear,
    this.maxModelYear,
    this.minPriceCents,
    this.maxPriceCents,
    this.seatingCapacities,
    this.transmission,
    this.minRating,
    this.maxDistanceKm,
    this.verifiedChauffeurOnly = false,
    this.verifiedVehicleOnly = false,
    this.availableNow = false,
    this.amenities,
    this.addonIds,
  });

  /// Creates a copy of this query with the given fields replaced.
  ///
  /// Nullable filter fields additionally accept an explicit-clear flag
  /// (`clear<FieldName>: true`) because a plain `null` argument is
  /// indistinguishable from "leave unchanged". Callers that need to REMOVE a
  /// filter must pass the matching clear flag instead of `null`.
  VehicleSearchQuery copyWith({
    String? pickupLocation,
    String? destination,
    DateTime? eventDate,
    String? eventTime,
    String? occasionId,
    int? passengerCount,
    List<String>? vehicleCategories,
    int? minModelYear,
    int? maxModelYear,
    int? minPriceCents,
    int? maxPriceCents,
    List<int>? seatingCapacities,
    String? transmission,
    double? minRating,
    double? maxDistanceKm,
    bool? verifiedChauffeurOnly,
    bool? verifiedVehicleOnly,
    bool? availableNow,
    List<String>? amenities,
    List<String>? addonIds,
    bool clearPickupLocation = false,
    bool clearDestination = false,
    bool clearEventDate = false,
    bool clearEventTime = false,
    bool clearOccasionId = false,
    bool clearPassengerCount = false,
    bool clearVehicleCategories = false,
    bool clearMinModelYear = false,
    bool clearMaxModelYear = false,
    bool clearMinPriceCents = false,
    bool clearMaxPriceCents = false,
    bool clearSeatingCapacities = false,
    bool clearTransmission = false,
    bool clearMinRating = false,
    bool clearMaxDistanceKm = false,
    bool clearAmenities = false,
    bool clearAddonIds = false,
  }) {
    return VehicleSearchQuery(
      pickupLocation: clearPickupLocation ? null : (pickupLocation ?? this.pickupLocation),
      destination: clearDestination ? null : (destination ?? this.destination),
      eventDate: clearEventDate ? null : (eventDate ?? this.eventDate),
      eventTime: clearEventTime ? null : (eventTime ?? this.eventTime),
      occasionId: clearOccasionId ? null : (occasionId ?? this.occasionId),
      passengerCount: clearPassengerCount ? null : (passengerCount ?? this.passengerCount),
      vehicleCategories: clearVehicleCategories
          ? null
          : (vehicleCategories ?? this.vehicleCategories),
      minModelYear: clearMinModelYear ? null : (minModelYear ?? this.minModelYear),
      maxModelYear: clearMaxModelYear ? null : (maxModelYear ?? this.maxModelYear),
      minPriceCents: clearMinPriceCents ? null : (minPriceCents ?? this.minPriceCents),
      maxPriceCents: clearMaxPriceCents ? null : (maxPriceCents ?? this.maxPriceCents),
      seatingCapacities: clearSeatingCapacities
          ? null
          : (seatingCapacities ?? this.seatingCapacities),
      transmission: clearTransmission ? null : (transmission ?? this.transmission),
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxDistanceKm: clearMaxDistanceKm ? null : (maxDistanceKm ?? this.maxDistanceKm),
      verifiedChauffeurOnly:
          verifiedChauffeurOnly ?? this.verifiedChauffeurOnly,
      verifiedVehicleOnly: verifiedVehicleOnly ?? this.verifiedVehicleOnly,
      availableNow: availableNow ?? this.availableNow,
      amenities: clearAmenities ? null : (amenities ?? this.amenities),
      addonIds: clearAddonIds ? null : (addonIds ?? this.addonIds),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VehicleSearchQuery &&
          runtimeType == other.runtimeType &&
          pickupLocation == other.pickupLocation &&
          destination == other.destination &&
          eventDate == other.eventDate &&
          eventTime == other.eventTime &&
          occasionId == other.occasionId &&
          passengerCount == other.passengerCount &&
          listEquals(vehicleCategories, other.vehicleCategories) &&
          minModelYear == other.minModelYear &&
          maxModelYear == other.maxModelYear &&
          minPriceCents == other.minPriceCents &&
          maxPriceCents == other.maxPriceCents &&
          listEquals(seatingCapacities, other.seatingCapacities) &&
          transmission == other.transmission &&
          minRating == other.minRating &&
          maxDistanceKm == other.maxDistanceKm &&
          verifiedChauffeurOnly == other.verifiedChauffeurOnly &&
          verifiedVehicleOnly == other.verifiedVehicleOnly &&
          availableNow == other.availableNow &&
          listEquals(amenities, other.amenities) &&
          listEquals(addonIds, other.addonIds);

  @override
  int get hashCode =>
      pickupLocation.hashCode ^
      destination.hashCode ^
      eventDate.hashCode ^
      eventTime.hashCode ^
      occasionId.hashCode ^
      passengerCount.hashCode ^
      vehicleCategories.hashCode ^
      minModelYear.hashCode ^
      maxModelYear.hashCode ^
      minPriceCents.hashCode ^
      maxPriceCents.hashCode ^
      seatingCapacities.hashCode ^
      transmission.hashCode ^
      minRating.hashCode ^
      maxDistanceKm.hashCode ^
      verifiedChauffeurOnly.hashCode ^
      verifiedVehicleOnly.hashCode ^
      availableNow.hashCode ^
      amenities.hashCode ^
      addonIds.hashCode;
}
