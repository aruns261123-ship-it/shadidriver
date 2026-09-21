/// Occasion-based service category (e.g., Wedding Cars, Baraat, Vidai).
class ServiceCategory {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? assetPath;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.assetPath,
  });
}
