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
  }) {
    return VehicleSearchQuery(
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destination: destination ?? this.destination,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      occasionId: occasionId ?? this.occasionId,
      passengerCount: passengerCount ?? this.passengerCount,
      vehicleCategories: vehicleCategories ?? this.vehicleCategories,
      minModelYear: minModelYear ?? this.minModelYear,
      maxModelYear: maxModelYear ?? this.maxModelYear,
      minPriceCents: minPriceCents ?? this.minPriceCents,
      maxPriceCents: maxPriceCents ?? this.maxPriceCents,
      seatingCapacities: seatingCapacities ?? this.seatingCapacities,
      transmission: transmission ?? this.transmission,
      minRating: minRating ?? this.minRating,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      verifiedChauffeurOnly:
          verifiedChauffeurOnly ?? this.verifiedChauffeurOnly,
      verifiedVehicleOnly: verifiedVehicleOnly ?? this.verifiedVehicleOnly,
      availableNow: availableNow ?? this.availableNow,
      amenities: amenities ?? this.amenities,
      addonIds: addonIds ?? this.addonIds,
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
