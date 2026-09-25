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
import 'dto/public_vehicle_dto.dart';

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

  /// Both the list and detail payloads share one shape, and there is exactly
  /// one mapper for it ([PublicVehicleDto]) so screens cannot drift apart.
  VehicleSummary _mapSummaryFromWire(Map<String, dynamic> json) =>
      PublicVehicleDto.toSummary(json);

  VehicleSummary _mapSummaryFromDetailsWire(Map<String, dynamic> json) =>
      PublicVehicleDto.toSummary(json);

  VehicleDetails _mapDetailsFromWire(Map<String, dynamic> json) {
    final vehicleClass = (json['vehicle_class'] as String?) ?? 'Luxury Sedan';
    final pricePaise = int.tryParse('${json['price_indicator_paise']}');
    final amenities = (json['amenities'] as List?)?.cast<String>() ?? const [];
    final ceremonies =
        (json['suitable_ceremonies'] as List?)?.cast<String>() ?? const [];
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
      transmission: json['transmission'] as String?,
      verificationStatus:
          (json['verification_status'] as String?) ?? 'APPROVED',
      galleryUrls: rawPhotos,
      // Editorial copy is a backend concern; no client-side invention.
      suitabilityInfo: (json['suitability_info'] as String?) ?? '',
      suitableCeremonies: ceremonies,
      amenities: amenities,
      // Ceremonial add-ons are a SERVER-priced catalog. The client must never
      // fabricate priced packages, so this stays empty until the catalog
      // endpoint supplies them, and the section hides itself meanwhile.
      ceremonialAddons: const <ServiceAddon>[],
      pricing: pricePaise == null
          ? const PricingSummary.unavailable()
          : PricingSummary(basePriceCents: pricePaise, billingUnit: 'DAY'),
      // Chauffeur identity is never part of a customer-facing vehicle payload.
      hasVerifiedChauffeur: (json['has_verified_chauffeur'] as bool?) ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      isAvailableNow: (json['is_available'] as bool?) ?? true,
    );
  }

  static String _humanizeClass(String raw) =>
      PublicVehicleDto.humanizeClass(raw);
}
