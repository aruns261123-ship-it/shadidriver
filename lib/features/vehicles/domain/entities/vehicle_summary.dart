import 'pricing_summary.dart';

/// Vehicle summary domain entity representing a fleet asset in the marketplace.
class VehicleSummary {
  final String id;
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

  const VehicleSummary({
    required this.id,
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
  });
}
