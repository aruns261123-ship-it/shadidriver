import '../../../../core/utils/currency_formatter.dart';
import '../../../vehicles/domain/entities/vehicle_summary.dart';

/// UI-specific presentation model for a Vehicle Card.
/// Bridges domain entities to high-fidelity UI requirements.
class VehicleCardViewModel {
  final String id;
  final String title;

  /// The reference spec line: `SUV · 5 seats · Automatic`.
  final String subtitle;
  final String? imageUrl;

  /// The reference's per-card strong price figure + unit (₹21.88 /km).
  final String priceText;
  final String priceUnit;

  /// The reference's "Estimated fare" figure (₹3,000+).
  final String fareEstimateText;

  /// The reference's gold "Premium" badge shows for premium/luxury classes.
  final bool isPremium;

  final bool hasVerifiedChauffeur;
  final bool isVerifiedVehicle;
  final bool isAvailable;

  const VehicleCardViewModel({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.priceText,
    required this.priceUnit,
    required this.fareEstimateText,
    required this.isPremium,
    required this.hasVerifiedChauffeur,
    required this.isVerifiedVehicle,
    required this.isAvailable,
  });

  factory VehicleCardViewModel.fromEntity(VehicleSummary entity) {
    final transmission = _transmissionLabel(entity.transmission);
    final specParts = <String>[
      entity.vehicleClass,
      '${entity.seatingCapacity} seats',
      ?transmission,
    ];
    final vehicleClassUpper = entity.vehicleClass.toUpperCase();
    return VehicleCardViewModel(
      id: entity.id,
      title: '${entity.make} ${entity.model}'.trim(),
      // Reference composition: class · seats · transmission.
      subtitle: specParts.join(' · '),
      imageUrl: entity.imageUrl,
      // No approved tariff means no price to show. Rendering the zero-valued
      // placeholder would advertise the car at "Rs 0".
      priceText: entity.pricing.isUnavailable
          ? 'On request'
          : CurrencyFormatter.formatPaise(entity.pricing.basePriceCents),
      priceUnit: entity.pricing.isUnavailable
          ? ''
          : entity.pricing.formattedUnit,
      // Estimated fare mirrors the per-trip base figure with the reference's
      // "+" (final checkout totals are the backend's authority).
      fareEstimateText: entity.pricing.isUnavailable
          ? 'On request'
          : '${CurrencyFormatter.formatPaise(entity.pricing.basePriceCents)}+',
      isPremium:
          vehicleClassUpper.contains('PREMIUM') ||
          vehicleClassUpper.contains('LUXURY'),
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

  static String? _transmissionLabel(String? wire) {
    switch (wire) {
      case 'AUTOMATIC':
        return 'Automatic';
      case 'MANUAL':
        return 'Manual';
      default:
        return null;
    }
  }
}
