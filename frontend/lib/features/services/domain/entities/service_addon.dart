import '../../../../features/vehicles/domain/entities/pricing_summary.dart';

/// Configurable service package or add-on (e.g., Royal Baraat, VIP Guest Transfer).
class ServiceAddon {
  final String id;
  final String name;
  final String description;
  final List<String> features;
  final PricingSummary pricing;
  final String? assetPath;

  const ServiceAddon({
    required this.id,
    required this.name,
    required this.description,
    required this.features,
    required this.pricing,
    this.assetPath,
  });
}
