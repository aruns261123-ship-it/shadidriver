import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../../search/domain/entities/search_query.dart';
import '../../search/domain/entities/search_sort.dart';
import '../../search/domain/engines/vehicle_search_engine.dart';
import '../../services/domain/entities/service_addon.dart';
import '../domain/entities/pricing_summary.dart';
import '../domain/entities/vehicle_details.dart';
import '../domain/entities/vehicle_summary.dart';
import '../domain/repositories/vehicle_repository.dart';

/// Real backend implementation of [VehicleRepository] communicating with the
/// NestJS `/api/v1/vehicles` endpoints.
class VehicleApiRepository implements VehicleRepository {
  final ApiClient _client;

  VehicleApiRepository(this._client);

  static const _basePath = '${AppConstants.apiV1Prefix}/vehicles';

  @override
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: {
          'limit': 50,
          if (categoryId != null && categoryId.isNotEmpty)
            'serviceCategoryId': categoryId,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final list = (data['items'] as List?) ??
          (data['vehicles'] as List?) ??
          const [];
      final vehicles = list
          .whereType<Map<String, dynamic>>()
          .map(_mapSummaryFromWire)
          .toList();
      return Result.success(vehicles);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<VehicleSummary>>> getFeaturedVehicles() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: {'limit': 6},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final list = (data['items'] as List?) ??
          (data['vehicles'] as List?) ??
          const [];
      final vehicles = list
          .whereType<Map<String, dynamic>>()
          .map(_mapSummaryFromWire)
          .toList();
      return Result.success(vehicles);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<VehicleSummary>> getVehicleById(String vehicleId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '$_basePath/$vehicleId',
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_mapSummaryFromDetailsWire(data));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<VehicleDetails>> getVehicleDetails(String vehicleId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '$_basePath/$vehicleId',
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_mapDetailsFromWire(data));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<VehicleSummary>>> searchVehicles({
    required VehicleSearchQuery query,
    required SearchSort sort,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': 50,
        if (query.pickupLocation != null && query.pickupLocation!.isNotEmpty)
          'city': query.pickupLocation,
        if (query.passengerCount != null && query.passengerCount! > 0)
          'minSeatingCapacity': query.passengerCount,
        if (query.vehicleCategories != null &&
            query.vehicleCategories!.isNotEmpty)
          'vehicleClass': query.vehicleCategories!.first,
      };

      final response = await _client.get<Map<String, dynamic>>(
        _basePath,
        queryParameters: queryParams,
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final list = (data['items'] as List?) ??
          (data['vehicles'] as List?) ??
          const [];
      var vehicles = list
          .whereType<Map<String, dynamic>>()
          .map(_mapSummaryFromWire)
          .toList();

      // Apply client-side search filtering (amenities, price range, transmission) and sort
      final filtered = VehicleSearchEngine.search(
        vehicles: vehicles,
        query: query,
        sort: sort,
      );
      return Result.success(filtered);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // JSON Mappers
  // ---------------------------------------------------------------------------

  VehicleSummary _mapSummaryFromWire(Map<String, dynamic> json) {
    final vehicleClass = (json['vehicle_class'] as String?) ?? 'Luxury Sedan';
    final pricePaise = int.tryParse('${json['base_price_paise']}') ?? 2500000;
    final rating = (json['average_rating'] as num?)?.toDouble() ?? 4.9;
    final amenities = (json['amenities'] as List?)?.cast<String>() ?? const [];

    return VehicleSummary(
      id: (json['id'] as String?) ?? '',
      make: (json['make'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 2024,
      vehicleClass: _humanizeClass(vehicleClass),
      registrationNumber:
          (json['fleet_code'] as String?) ??
          (json['registration_number'] as String?) ??
          '',
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 4,
      verificationStatus:
          (json['verification_status'] as String?) ?? 'APPROVED',
      imageUrl: json['image_url'] as String?,
      rating: rating,
      reviewCount: 120,
      hasVerifiedChauffeur: json['chauffeur_id'] != null,
      pricing: PricingSummary(basePriceCents: pricePaise, billingUnit: 'DAY'),
      distanceKm: 2.5,
      transmission: 'AUTOMATIC',
      amenities: amenities,
      isAvailableNow: (json['is_available'] as bool?) ?? true,
      suitableCeremonies: _ceremoniesForClass(vehicleClass),
    );
  }

  VehicleSummary _mapSummaryFromDetailsWire(Map<String, dynamic> json) {
    final vehicleClass = (json['vehicle_class'] as String?) ?? 'Luxury Sedan';
    final pricePaise = int.tryParse('${json['base_price_paise']}') ?? 2500000;
    final chauffeur = json['chauffeur'] as Map<String, dynamic>?;
    final driverRating = (chauffeur?['average_rating'] as num?)?.toDouble();
    final amenities = (json['amenities'] as List?)?.cast<String>() ?? const [];

    return VehicleSummary(
      id: (json['id'] as String?) ?? '',
      make: (json['make'] as String?) ?? '',
      model: (json['model'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 2024,
      vehicleClass: _humanizeClass(vehicleClass),
      registrationNumber:
          (json['fleet_code'] as String?) ??
          (json['registration_number'] as String?) ??
          '',
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 4,
      verificationStatus:
          (json['verification_status'] as String?) ?? 'APPROVED',
      imageUrl: json['image_url'] as String?,
      rating: driverRating ?? 4.9,
      reviewCount: 120,
      hasVerifiedChauffeur: chauffeur != null,
      pricing: PricingSummary(basePriceCents: pricePaise, billingUnit: 'DAY'),
      distanceKm: 2.5,
      transmission: 'AUTOMATIC',
      amenities: amenities,
      isAvailableNow: (json['is_available'] as bool?) ?? true,
      suitableCeremonies: _ceremoniesForClass(vehicleClass),
    );
  }

  VehicleDetails _mapDetailsFromWire(Map<String, dynamic> json) {
    final vehicleClass = (json['vehicle_class'] as String?) ?? 'Luxury Sedan';
    final pricePaise = int.tryParse('${json['base_price_paise']}') ?? 2500000;
    final chauffeur = json['chauffeur'] as Map<String, dynamic>?;
    final chauffeurId = (chauffeur?['id'] as String?) ?? '';
    final driverRating =
        (chauffeur?['average_rating'] as num?)?.toDouble() ?? 4.9;
    final amenities = (json['amenities'] as List?)?.cast<String>() ?? const [];
    final rawPhotos = (json['photos'] as List?)?.cast<String>() ?? const [];

    final make = (json['make'] as String?) ?? '';
    final model = (json['model'] as String?) ?? '';

    return VehicleDetails(
      id: (json['id'] as String?) ?? '',
      make: make,
      model: model,
      year: (json['year'] as num?)?.toInt() ?? 2024,
      vehicleClass: _humanizeClass(vehicleClass),
      seatingCapacity: (json['seating_capacity'] as num?)?.toInt() ?? 4,
      transmission: 'AUTOMATIC',
      verificationStatus:
          (json['verification_status'] as String?) ?? 'APPROVED',
      galleryUrls: rawPhotos,
      suitabilityInfo:
          'Executive ceremonial mobility benchmark. Engineered for majestic processions with silent cabin acoustics and dual executive climate comfort.',
      suitableCeremonies: _ceremoniesForClass(vehicleClass),
      amenities: amenities,
      ceremonialAddons: const [
        ServiceAddon(
          id: 'addon_fresh_floral',
          name: 'Floral Vehicle Decoration',
          description:
              'Fresh seasonal floral garlands and bonnet arrangements.',
          features: ['Fresh Orchids / Roses', 'Paint-Safe Clamps'],
          pricing: PricingSummary(
            basePriceCents: 350000,
            billingUnit: 'PACKAGE',
          ),
        ),
        ServiceAddon(
          id: 'addon_baraat_attire',
          name: 'Chauffeur Safa & Jodhpuri Attire',
          description: 'Ceremonial silk safa and bandhgala uniform.',
          features: [
            'Custom Color Safa',
            'Bandhgala Suit',
            'Formal Etiquette',
          ],
          pricing: PricingSummary(
            basePriceCents: 150000,
            billingUnit: 'PACKAGE',
          ),
        ),
        ServiceAddon(
          id: 'addon_hamper',
          name: 'Welcome Refreshment Hamper',
          description: 'Premium chilled juices, dry fruits, and mint water.',
          features: [
            'Chilled Juices',
            'Dry Fruits Box',
            'Ceremonial Mineral Water',
          ],
          pricing: PricingSummary(
            basePriceCents: 80000,
            billingUnit: 'PACKAGE',
          ),
        ),
      ],
      pricing: PricingSummary(basePriceCents: pricePaise, billingUnit: 'DAY'),
      chauffeurId: chauffeurId,
      rating: driverRating,
      reviewCount: 120,
      isAvailableNow: (json['is_available'] as bool?) ?? true,
    );
  }

  static String _humanizeClass(String raw) {
    return switch (raw.toUpperCase()) {
      'LUXURY_SEDAN' => 'Luxury Sedan',
      'EXECUTIVE_MPV' => 'Executive MPV',
      'ULTRA_LUXURY' => 'Ultra Luxury',
      'PREMIUM_SUV' => 'Premium SUV',
      'VINTAGE' => 'Vintage',
      _ => raw,
    };
  }

  static List<String> _ceremoniesForClass(String raw) {
    return switch (raw.toUpperCase()) {
      'LUXURY_SEDAN' => const [
        'Baraat',
        'Groom Entry',
        'Reception',
        'Engagement',
      ],
      'EXECUTIVE_MPV' => const [
        'Guest Transport',
        'Airport VIP',
        'Family Escort',
      ],
      'ULTRA_LUXURY' => const [
        'Bride Entry',
        'Groom Entry',
        'Vidai',
        'Royal Reception',
      ],
      _ => const ['Baraat', 'Vidai', 'Reception'],
    };
  }
}
