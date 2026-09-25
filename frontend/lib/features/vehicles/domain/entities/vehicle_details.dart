import 'pricing_summary.dart';
import '../../../../features/services/domain/entities/service_addon.dart';

/// Comprehensive vehicle details domain entity for deep discovery.
class VehicleDetails {
  final String id;
  final String make;
  final String model;
  final int year;
  final String vehicleClass;
  final int seatingCapacity;
  final String? transmission;
  final String verificationStatus;
  final List<String> galleryUrls;
  final String suitabilityInfo;
  final List<String> suitableCeremonies;
  final List<String> amenities;
  final List<ServiceAddon> ceremonialAddons;
  final PricingSummary pricing;

  /// Whether ShadiDriver can source a VERIFIED chauffeur for this vehicle.
  ///
  /// Deliberately a boolean: chauffeur identity is internal operational data
  /// and is never carried on a customer-facing vehicle payload.
  final bool hasVerifiedChauffeur;
  final double rating;
  final int reviewCount;
  final bool isAvailableNow;

  const VehicleDetails({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.vehicleClass,
    required this.seatingCapacity,
    this.transmission,
    required this.verificationStatus,
    required this.galleryUrls,
    required this.suitabilityInfo,
    this.suitableCeremonies = const [],
    required this.amenities,
    required this.ceremonialAddons,
    required this.pricing,
    this.hasVerifiedChauffeur = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isAvailableNow = false,
  });
}
