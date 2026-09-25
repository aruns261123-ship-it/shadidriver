import '../../../../core/utils/currency_formatter.dart';
import '../../../vehicles/domain/entities/vehicle_summary.dart';

/// UI-specific presentation model for a Vehicle Card.
/// Bridges domain entities to high-fidelity UI requirements.
class VehicleCardViewModel {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String ratingText;
  final String reviewCountText;
  final String distanceText;
  final String priceText;
  final String priceUnit;
  final bool hasVerifiedChauffeur;
  final bool isVerifiedVehicle;
  final bool isAvailable;

  const VehicleCardViewModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.ratingText,
    required this.reviewCountText,
    required this.distanceText,
    required this.priceText,
    required this.priceUnit,
    required this.hasVerifiedChauffeur,
    required this.isVerifiedVehicle,
    required this.isAvailable,
  });

  factory VehicleCardViewModel.fromEntity(VehicleSummary entity) {
    return VehicleCardViewModel(
      id: entity.id,
      title: '${entity.make} ${entity.model}',
      subtitle: '${entity.year} • ${entity.vehicleClass}',
      imageUrl: entity.imageUrl,
      ratingText: entity.rating.toStringAsFixed(1),
      reviewCountText: '(${entity.reviewCount})',
      distanceText: entity.distanceKm != null ? '${entity.distanceKm} km' : '',
      // No approved tariff means no price to show. Rendering the zero-valued
      // placeholder would advertise the car at "Rs 0".
      priceText: entity.pricing.isUnavailable
          ? 'On request'
          : CurrencyFormatter.formatPaise(entity.pricing.basePriceCents),
      priceUnit: entity.pricing.isUnavailable ? '' : entity.pricing.formattedUnit,
      hasVerifiedChauffeur: entity.hasVerifiedChauffeur,
      // The backend's verified state is APPROVED; comparing against 'VERIFIED'
      // made every card render as unverified.
      isVerifiedVehicle:
          entity.verificationStatus == 'APPROVED' ||
          entity.verificationStatus == 'VERIFIED',
      // Sourced from the server, never assumed.
      isAvailable: entity.isAvailableNow,
    );
  }
}
