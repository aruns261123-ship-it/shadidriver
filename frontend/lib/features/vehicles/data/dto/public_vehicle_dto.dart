import '../../domain/entities/pricing_summary.dart';
import '../../domain/entities/vehicle_summary.dart';

/// The ONE place that knows the public vehicle wire format.
///
/// Mirrors `backend/src/vehicles/dto/public-vehicle.dto.ts`. Every customer
/// surface that renders a vehicle — catalog, search, favourites, recently
/// viewed — maps through here, so the contract cannot drift between screens.
///
/// Two rules this mapper enforces:
///   * chauffeur identity is never present in the payload and is never read;
///     trust is the explicit `has_verified_chauffeur` boolean the backend owns;
///   * anything the backend did not publish (distance, transmission, a tariff)
///     is left unknown rather than invented client-side.
abstract final class PublicVehicleDto {
  /// Keys the backend may send for a public/customer vehicle. Used by contract
  /// tests to prove the client does not depend on fields outside the contract.
  static const Set<String> contractFields = {
    'id',
    'vehicle_type_id',
    'fleet_code',
    'make',
    'model',
    'display_name',
    'year',
    'vehicle_class',
    'seating_capacity',
    'city',
    'image_url',
    'amenities',
    'verification_status',
    'is_available',
    'has_verified_chauffeur',
    'rating',
    'review_count',
    'price_indicator_paise',
    'color',
    'fuel_type',
    'air_conditioning',
    'is_vintage',
    'service_areas',
    'photos',
    'documents_summary',
    'suitable_ceremonies',
    'distance_km',
    'transmission',
    'suitability_info',
  };

  /// Maps a public list item (or detail payload) onto [VehicleSummary].
  ///
  /// [registrationsVisible] is for the future partner/admin surfaces only;
  /// a customer payload never carries `registration_number`.
  static VehicleSummary toSummary(
    Map<String, dynamic> json, {
    bool registrationsVisible = false,
  }) {
    final vehicleClass = (json['vehicle_class'] as String?) ?? 'Luxury Sedan';
    final pricePaise = int.tryParse('${json['price_indicator_paise']}');
    final amenities = (json['amenities'] as List?)?.cast<String>() ?? const [];
    final ceremonies =
        (json['suitable_ceremonies'] as List?)?.cast<String>() ?? const [];

    return VehicleSummary(
      id: (json['id'] as String?) ?? '',
      make: (json['make'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 2024,
      vehicleClass: humanizeClass(vehicleClass),
      registrationNumber: registrationsVisible
          ? ((json['registration_number'] as String?) ?? '')
          : ((json['fleet_code'] as String?) ?? ''),
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 4,
      verificationStatus:
          (json['verification_status'] as String?) ?? 'APPROVED',
      imageUrl: json['image_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      hasVerifiedChauffeur: (json['has_verified_chauffeur'] as bool?) ?? false,
      pricing: pricePaise == null
          ? const PricingSummary.unavailable()
          : PricingSummary(basePriceCents: pricePaise, billingUnit: 'DAY'),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      transmission: json['transmission'] as String?,
      amenities: amenities,
      isAvailableNow: (json['is_available'] as bool?) ?? true,
      suitableCeremonies: ceremonies,
    );
  }

  /// Extracts the `items` array from a list envelope's `data`.
  static List<VehicleSummary> toSummaryList(Object? data) {
    if (data is! Map<String, dynamic>) return const [];
    final list = (data['items'] as List?) ?? (data['vehicles'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(toSummary)
        .toList();
  }

  /// Presentation label for a backend vehicle class token.
  static String humanizeClass(String raw) {
    return switch (raw.toUpperCase()) {
      'LUXURY_SEDAN' => 'Luxury Sedan',
      'EXECUTIVE_MPV' => 'Executive MPV',
      'ULTRA_LUXURY' => 'Ultra Luxury',
      'PREMIUM_SUV' => 'Premium SUV',
      'VINTAGE' => 'Vintage',
      _ => raw,
    };
  }
}
