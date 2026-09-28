import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/partner_enums.dart';
import '../domain/entities/partner_profile.dart';
import '../domain/entities/partner_vehicle.dart';
import '../domain/repositories/partner_repository.dart';

/// Real API implementation of [PartnerRepository].
///
/// Wire format: the backend snake_case views (viewProfile / viewVehicle /
/// viewVersion). Every endpoint requires the partner's JWT — handled by the
/// shared AuthInterceptor; nothing here touches tokens.
class PartnerApiRepository implements PartnerRepository {
  final ApiClient _client;

  PartnerApiRepository(this._client);

  static const String _base = '/api/v1/partner';

  @override
  Future<Result<PartnerProfile>> register(PartnerRegistrationDraft draft) =>
      _postProfile('$_base/registration', draft.toWire());

  @override
  Future<Result<PartnerProfile>> getProfile() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('$_base/profile');
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_profileFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }  @override
  Future<Result<PartnerProfile>> updateProfile(
    PartnerRegistrationDraft draft,
  ) => _postProfile('$_base/profile', draft.toWire(), patch: true);

  @override
  Future<Result<PartnerFleet>> listFleet() async {
    try {
      final response =
          await _client.get<Map<String, dynamic>>('$_base/vehicles');
      final data = ApiEnvelope.fromJson(response.data).data;
      final map = (data ?? {}) as Map<String, dynamic>;
      final items = (map['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_vehicleFromWire)
          .toList();
      return Result.success(
        PartnerFleet(items: items, total: (map['total'] as num?)?.toInt() ?? items.length),
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<PartnerVehicle>> addVehicle(PartnerVehicleDraft draft) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '$_base/vehicles',
        data: draft.toWire(),
      );
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_vehicleFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<PartnerVehicle>> updateVehicle(
    String vehicleId,
    PartnerVehicleEditDraft draft,
  ) async {
    try {
      final response = await _client.put<Map<String, dynamic>>(
        '$_base/vehicles/$vehicleId',
        data: draft.toWire(),
      );
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_vehicleFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> removeVehicle(String vehicleId) async {
    try {
      await _client.delete<Map<String, dynamic>>('$_base/vehicles/$vehicleId');
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> addVehicleDocument(
    String vehicleId,
    VehicleDocumentDraft draft,
  ) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '$_base/vehicles/$vehicleId/documents',
        data: draft.toWire(),
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<List<VehicleTariff>>> listTariffs(String vehicleId) async {
    try {
      final response = await _client
          .get<Map<String, dynamic>>('$_base/vehicles/$vehicleId/pricing');
      final data = ApiEnvelope.fromJson(response.data).data;
      final map = (data ?? {}) as Map<String, dynamic>;
      final items = (map['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_tariffFromWire)
          .toList();
      return Result.success(items);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<VehicleTariff>> submitTariff(
    String vehicleId,
    VehicleTariffDraft draft,
  ) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '$_base/vehicles/$vehicleId/pricing',
        data: draft.toWire(),
      );
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_tariffFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<PartnerProfile>> submitForVerification() async {
    try {
      final response =
          await _client.post<Map<String, dynamic>>('$_base/submit');
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_profileFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  // ------------------------------------------------------------- internals

  Future<Result<PartnerProfile>> _postProfile(
    String path,
    Map<String, dynamic> body, {
    bool patch = false,
  }) async {
    try {
      final response = patch
          ? await _client.patch<Map<String, dynamic>>(path, data: body)
          : await _client.post<Map<String, dynamic>>(path, data: body);
      final data = ApiEnvelope.fromJson(response.data).data;
      return Result.success(_profileFromWire((data ?? {}) as Map<String, dynamic>));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  static PartnerProfile _profileFromWire(Map<String, dynamic> j) =>
      PartnerProfile(
        id: (j['id'] as String?) ?? '',
        companyName: (j['company_name'] as String?) ?? '',
        contactName: j['contact_name'] as String?,
        baseCity: j['base_city'] as String?,
        serviceCities: (j['service_cities'] as List?)?.cast<String>() ?? const [],
        languagesSpoken:
            (j['languages_spoken'] as List?)?.cast<String>() ?? const [],
        experienceYears: (j['experience_years'] as num?)?.toInt() ?? 0,
        verificationStatus:
            PartnerVerificationStatus.fromWire(j['verification_status'] as String?),
        submittedAt: _date(j['submitted_at']),
        reviewedAt: _date(j['reviewed_at']),
        decisionReason: j['decision_reason'] as String?,
        vehicleCount: (j['vehicle_count'] as num?)?.toInt() ?? 0,
        documentCount: (j['document_count'] as num?)?.toInt() ?? 0,
      );

  static PartnerVehicle _vehicleFromWire(Map<String, dynamic> j) =>
      PartnerVehicle(
        id: (j['id'] as String?) ?? '',
        fleetCode: (j['fleet_code'] as String?) ?? '',
        vehicleTypeId: (j['vehicle_type_id'] as String?) ?? '',
        displayName: j['display_name'] as String?,
        seatingCapacity: (j['seating_capacity'] as num?)?.toInt(),
        vehicleClass: j['vehicle_class'] as String?,
        year: (j['year'] as num?)?.toInt() ?? 0,
        registrationNumber: (j['registration_number'] as String?) ?? '',
        color: (j['color'] as String?) ?? '',
        fuelType: (j['fuel_type'] as String?) ?? '',
        transmission: (j['transmission'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        serviceAreas: (j['service_areas'] as List?)?.cast<String>() ?? const [],
        amenities: (j['amenities'] as List?)?.cast<String>() ?? const [],
        photoUrls: (j['photo_urls'] as List?)?.cast<String>() ?? const [],
        verificationStatus:
            PartnerVerificationStatus.fromWire(j['verification_status'] as String?),
        isActive: (j['is_active'] as bool?) ?? true,
        isAvailable: (j['is_available'] as bool?) ?? true,
        isBookable: (j['is_bookable'] as bool?) ?? false,
        documents: ((j['documents'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map((d) => PartnerVehicleDocument(
                      type: (d['type'] as String?) ?? '',
                      status: PartnerVerificationStatus.fromWire(
                          d['status'] as String?),
                      expiresAt: _date(d['expires_at']),
                    )))
            .toList(),
      );

  static VehicleTariff _tariffFromWire(Map<String, dynamic> j) => VehicleTariff(
        id: (j['id'] as String?) ?? '',
        version: (j['version'] as num?)?.toInt() ?? 1,
        currency: (j['currency'] as String?) ?? 'INR',
        localIncludedKm: (j['local_included_km'] as num?)?.toInt(),
        localAmountPaise: j['local_amount_paise'] as String?,
        perKmPaise: j['per_km_paise'] as String?,
        hourlyPaise: j['hourly_paise'] as String?,
        extraHourPaise: j['extra_hour_paise'] as String?,
        fullDayPaise: j['full_day_paise'] as String?,
        overnightPaise: j['overnight_paise'] as String?,
        outstationPerDayPaise: j['outstation_per_day_paise'] as String?,
        outstationPerKmPaise: j['outstation_per_km_paise'] as String?,
        status: TariffStatus.fromWire(j['status'] as String?),
        submittedAt: _date(j['submitted_at']) ?? DateTime.now(),
        reviewedAt: _date(j['reviewed_at']),
        decisionReason: j['decision_reason'] as String?,
        effectiveFrom: _date(j['effective_from']),
      );

  static DateTime? _date(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
