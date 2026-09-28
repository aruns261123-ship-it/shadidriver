import 'pricing_summary.dart';

/// Vehicle summary domain entity representing a fleet asset in the marketplace.
class VehicleSummary {
  final String id;

  /// Backend vehicle-TYPE id (e.g. `VT_INNOVA_CRYSTA`). The customer books
  /// "an Innova Crysta", not a specific plate — this is what a booking line
  /// references. Empty when the payload did not carry it (never in real mode).
  final String vehicleTypeId;
  final String make;
  final String model;
  final int year;
  final String vehicleClass;
  final String registrationNumber;
  final int seatingCapacity;
  final String verificationStatus;
  final String? imageUrl;
  final double rating;
  final int reviewCount;
  final bool hasVerifiedChauffeur;
  final PricingSummary pricing;
  final double? distanceKm;
  final String? transmission; // 'AUTOMATIC', 'MANUAL'
  final List<String> amenities;
  final bool isAvailableNow;

  /// Ceremonial occasions this vehicle is suited for, e.g. 'Baraat',
  /// 'Bride Entry', 'Guest Transport'. Used by search occasion filtering.
  final List<String> suitableCeremonies;

  const VehicleSummary({
    required this.id,
    this.vehicleTypeId = '',
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleClass,
    required this.registrationNumber,
    required this.seatingCapacity,
    required this.verificationStatus,
    this.imageUrl,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.hasVerifiedChauffeur = false,
    required this.pricing,
    this.distanceKm,
    this.transmission,
    this.amenities = const [],
    this.isAvailableNow = false,
    this.suitableCeremonies = const [],
  });
}
