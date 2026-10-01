import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/partner_providers.dart';
import 'package:shadidriver/core/network/api_response.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_enums.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_profile.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_vehicle.dart';
import 'package:shadidriver/features/partner/domain/repositories/partner_repository.dart';
import 'package:shadidriver/features/partner/presentation/controllers/partner_onboarding_controller.dart';

/// Deterministic fake repository. Errors are injected as raw transport
/// exceptions and converted via mapDioError into Result.failure, exactly like
/// the real API repository does.
class _FakePartnerRepository implements PartnerRepository {
  PartnerProfile? profile;
  List<PartnerVehicle> fleet = const [];
  final List<String> calls = [];
  final List<Object?> payloads = [];
  Object? throwOnNext;

  Future<Result<T>> _guard<T>(String op, Result<T> Function() body) async {
    calls.add(op);
    final error = throwOnNext;
    if (error != null) {
      throwOnNext = null;
      // The real repository never throws: every transport failure becomes a
      // typed Result.failure via mapDioError. Mirror that exactly.
      return Result.failure(mapDioError(error));
    }
    return body();
  }

  @override
  Future<Result<PartnerProfile>> register(PartnerRegistrationDraft draft) async {
    payloads.add(draft.toWire());
    return _guard('register', () {
      profile = _newProfile(draft.companyName, draft.baseCity);
      return Result.success(profile!);
    });
  }

  @override
  Future<Result<PartnerProfile>> getProfile() async {
    return _guard<PartnerProfile>('getProfile', () {
      if (profile == null) {
        return Result.failure(mapDioError(DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
            statusCode: 401,
            data: {
              'success': false,
              'error': {'code': 'AUTH_INVALID_TOKEN', 'message': 'Unauthorized'},
            },
          ),
        )));
      }
      return Result.success(profile!);
    });
  }

  @override
  Future<Result<PartnerProfile>> updateProfile(
      PartnerRegistrationDraft draft) async {
    payloads.add(draft.toWire());
    return _guard('updateProfile', () {
      final p = profile!;
      profile = PartnerProfile(
        id: p.id,
        companyName: draft.companyName,
        contactName: draft.contactName ?? p.contactName,
        baseCity: draft.baseCity,
        serviceCities: draft.serviceCities,
        languagesSpoken: draft.languagesSpoken,
        experienceYears: draft.experienceYears ?? p.experienceYears,
        verificationStatus: p.verificationStatus,
        submittedAt: p.submittedAt,
        reviewedAt: p.reviewedAt,
        decisionReason: p.decisionReason,
        vehicleCount: p.vehicleCount,
        documentCount: p.documentCount,
      );
      return Result.success(profile!);
    });
  }

  @override
  Future<Result<PartnerFleet>> listFleet() async {
    return _guard('listFleet', () {
      return Result.success(PartnerFleet(items: fleet, total: fleet.length));
    });
  }

  @override
  Future<Result<PartnerVehicle>> addVehicle(PartnerVehicleDraft draft) async {
    payloads.add(draft.toWire());
    return _guard('addVehicle', () {
      final v = _draftToVehicle(draft);
      fleet = [...fleet, v];
      return Result.success(v);
    });
  }

  @override
  Future<Result<PartnerVehicle>> updateVehicle(
      String vehicleId, PartnerVehicleEditDraft draft) async {
    payloads.add(draft.toWire());
    return _guard('updateVehicle', () {
      final idx = fleet.indexWhere((v) => v.id == vehicleId);
      final old = fleet[idx];
      final updated = PartnerVehicle(
        id: old.id,
        fleetCode: old.fleetCode,
        vehicleTypeId: old.vehicleTypeId,
        displayName: old.displayName,
        seatingCapacity: old.seatingCapacity,
        vehicleClass: old.vehicleClass,
        year: draft.yearOfManufacture ?? old.year,
        registrationNumber: old.registrationNumber,
        color: draft.color ?? old.color,
        fuelType: draft.fuelType ?? old.fuelType,
        transmission: draft.transmission ?? old.transmission,
        city: draft.city ?? old.city,
        serviceAreas: draft.serviceAreas ?? old.serviceAreas,
        amenities: draft.amenities ?? old.amenities,
        photoUrls: draft.photoUrls ?? old.photoUrls,
        verificationStatus: old.verificationStatus,
        isActive: old.isActive,
        isAvailable: old.isAvailable,
        isBookable: old.isBookable,
        documents: old.documents,
      );
      fleet = [...fleet]..[idx] = updated;
      return Result.success(updated);
    });
  }

  @override
  Future<Result<void>> removeVehicle(String vehicleId) async {
    return _guard('removeVehicle', () {
      fleet = fleet.where((v) => v.id != vehicleId).toList();
      return const Result.success(null);
    });
  }

  @override
  Future<Result<void>> addVehicleDocument(
      String vehicleId, VehicleDocumentDraft draft) async {
    return _guard('addVehicleDocument', () => const Result.success(null));
  }

  @override
  Future<Result<List<VehicleTariff>>> listTariffs(String vehicleId) async {
    return _guard('listTariffs', () => Result.success(const <VehicleTariff>[]));
  }

  @override
  Future<Result<VehicleTariff>> submitTariff(
      String vehicleId, VehicleTariffDraft draft) async {
    payloads.add(draft.toWire());
    return _guard('submitTariff', () {
      final tariff = VehicleTariff(
        id: 'tar-${calls.where((c) => c == 'submitTariff').length}',
        version: 1,
        currency: 'INR',
        localIncludedKm: draft.localIncludedKm,
        localAmountPaise: '${draft.localAmountPaise}',
        // Derived exactly like the server: round((fuel ÷ mileage + 10) × 100).
        perKmPaise:
            '${(((draft.fuelPricePerLitre / draft.mileageKmPerLitre) + 10) * 100).round()}',
        hourlyPaise: null,
        extraHourPaise: null,
        fullDayPaise: null,
        overnightPaise: null,
        outstationPerDayPaise: null,
        outstationPerKmPaise: null,
        status: TariffStatus.pendingReview,
        submittedAt: DateTime(2026, 9, 27),
        reviewedAt: null,
        decisionReason: null,
        effectiveFrom: null,
      );
      return Result.success(tariff);
    });
  }

  @override
  Future<Result<PartnerProfile>> submitForVerification() async {
    return _guard<PartnerProfile>('submitForVerification', () {
      if (fleet.isEmpty) {
        return Result.failure(mapDioError(DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/submit'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/partner/submit'),
            statusCode: 400,
            data: {
              'success': false,
              'error': {
                'code': 'VALIDATION_FAILED',
                'message':
                    'Add at least one vehicle before submitting for verification.',
              },
            },
          ),
        )));
      }
      final p = profile!;
      profile = _copyWithStatus(p, PartnerVerificationStatus.submitted);
      return Result.success(profile!);
    });
  }

  static PartnerProfile _newProfile(String company, String city) {
    return PartnerProfile(
      id: 'partner-1',
      companyName: company,
      contactName: 'Rakesh Sharma',
      baseCity: city,
      serviceCities: const ['Delhi NCR'],
      languagesSpoken: const ['Hindi'],
      experienceYears: 7,
      verificationStatus: PartnerVerificationStatus.pendingSubmission,
      submittedAt: null,
      reviewedAt: null,
      decisionReason: null,
    );
  }

  static PartnerProfile _copyWithStatus(
      PartnerProfile p, PartnerVerificationStatus status) {
    return PartnerProfile(
      id: p.id,
      companyName: p.companyName,
      contactName: p.contactName,
      baseCity: p.baseCity,
      serviceCities: p.serviceCities,
      languagesSpoken: p.languagesSpoken,
      experienceYears: p.experienceYears,
      verificationStatus: status,
      submittedAt: status == PartnerVerificationStatus.submitted
          ? DateTime(2026, 9, 27)
          : null,
      reviewedAt: null,
      decisionReason: null,
      vehicleCount: p.vehicleCount,
      documentCount: p.documentCount,
    );
  }

  static PartnerVehicle _draftToVehicle(PartnerVehicleDraft d) {
    return PartnerVehicle(
      id: 'vh-${d.registrationNumber.substring(6)}',
      fleetCode: 'SD-VH-${d.registrationNumber.substring(6)}',
      vehicleTypeId: d.vehicleTypeId,
      displayName: null,
      seatingCapacity: 5,
      vehicleClass: 'LUXURY_SUV',
      year: d.yearOfManufacture,
      registrationNumber: d.registrationNumber,
      color: d.color,
      fuelType: d.fuelType,
      transmission: d.transmission,
      city: d.city,
      serviceAreas: d.serviceAreas,
      amenities: d.amenities,
      photoUrls: d.photoUrls,
      verificationStatus: PartnerVerificationStatus.pendingSubmission,
      isActive: true,
      isAvailable: true,
      isBookable: false,
      documents: const [],
    );
  }
}

const _draft = PartnerRegistrationDraft(
  companyName: 'Sharma Wedding Fleets',
  baseCity: 'Delhi NCR',
);

const _thar = PartnerVehicleDraft(
  vehicleTypeId: 'VT_THAR',
  yearOfManufacture: 2024,
  registrationNumber: 'DL01AB1234',
  color: 'Everest White',
  fuelType: 'DIESEL',
  transmission: 'MANUAL',
  city: 'Delhi NCR',
);

const _scorpio = PartnerVehicleDraft(
  vehicleTypeId: 'VT_SCORPIO',
  yearOfManufacture: 2023,
  registrationNumber: 'DL02CD5678',
  color: 'Molten Black',
  fuelType: 'DIESEL',
  transmission: 'AUTOMATIC',
  city: 'Delhi NCR',
);

const _tariff = VehicleTariffDraft(
  localIncludedKm: 45,
  localAmountPaise: 300000,
  fuelPricePerLitre: 95,
  mileageKmPerLitre: 8,
);

void main() {
  late _FakePartnerRepository repo;
  late ProviderContainer container;

  PartnerOnboardingController ctrl() =>
      container.read(partnerOnboardingProvider.notifier);
  PartnerOnboardingState snap() => container.read(partnerOnboardingProvider);

  setUp(() async {
    repo = _FakePartnerRepository();
    container = ProviderContainer(overrides: [
      partnerRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    // build() schedules refreshProfile() as a microtask; drain it so call
    // sequences below are deterministic.
    container.read(partnerOnboardingProvider.notifier);
    await Future<void>.delayed(Duration.zero);
  });

  group('partner registration flow', () {
    test('register advances to fleet stage with profile saved', () async {
      final ok = await ctrl().saveProfile(_draft);

      expect(ok, isTrue);
      expect(snap().profile, isNotNull);
      expect(snap().profile!.companyName, 'Sharma Wedding Fleets');
      expect(snap().stage, OnboardingStage.fleet);
      expect(snap().errorMessage, isNull);
      expect(
          repo.calls.where((c) => c != 'getProfile'), equals(['register']));
    });

    test('existing partner edits via update, not re-registration', () async {
      await ctrl().saveProfile(_draft);
      await ctrl().saveProfile(const PartnerRegistrationDraft(
        companyName: 'Sharma Wedding Fleets',
        baseCity: 'Gurugram',
      ));

      expect(repo.calls.where((c) => c != 'getProfile'),
          ['register', 'updateProfile']);
      expect(snap().profile!.baseCity, 'Gurugram');
    });

    test('failed registration keeps partner on form with error', () async {
      repo.throwOnNext = DioException(
        requestOptions: RequestOptions(path: '/api/v1/partner/registration'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/v1/partner/registration'),
          statusCode: 500,
          data: {
            'success': false,
            'error': {'code': 'INTERNAL_ERROR', 'message': 'Server error'},
          },
        ),
      );
      final ok = await ctrl().saveProfile(_draft);

      expect(ok, isFalse);
      expect(snap().profile, isNull);
      expect(snap().errorMessage, isNotNull);
    });
  });

  group('fleet + vehicle flow', () {
    setUp(() async {
      repo.profile = _newPartnerProfile();
      await ctrl().saveProfile(_draft);
    });

    test('adds multiple vehicles: Thar and Scorpio both land in fleet',
        () async {
      await ctrl().saveVehicle(newVehicle: _thar);
      expect(snap().editingVehicle, isNotNull);
      expect(snap().stage, OnboardingStage.pricing);

      ctrl().backToFleet();
      // The fleet stage's "+ Add Vehicle" clears the editing vehicle first;
      // without it saveVehicle would update the Thar instead of adding.
      ctrl().startAddVehicle();
      await ctrl().saveVehicle(newVehicle: _scorpio);

      expect(repo.fleet, hasLength(2));
      expect(repo.fleet.map((v) => v.vehicleTypeId).toSet(),
          containsAll(['VT_THAR', 'VT_SCORPIO']));
      expect(repo.fleet.map((v) => v.registrationNumber).toSet(),
          containsAll(['DL01AB1234', 'DL02CD5678']));
    });

    test('loading the fleet preserves both vehicles (app-restart restore)',
        () async {
      await ctrl().saveVehicle(newVehicle: _thar);
      ctrl().backToFleet();
      ctrl().startAddVehicle();
      await ctrl().saveVehicle(newVehicle: _scorpio);
      ctrl().backToFleet();

      // Simulate a restart: brand-new controller state, same repo (server).
      final fresh = ProviderContainer(overrides: [
        partnerRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(fresh.dispose);
      await fresh.read(partnerOnboardingProvider.notifier).loadFleet();
      final restored = fresh.read(partnerOnboardingProvider);

      expect(restored.fleet!.total, 2);
      expect(restored.fleet!.items.map((v) => v.registrationNumber).toSet(),
          {'DL01AB1234', 'DL02CD5678'});
    });

    test('editing keeps identity fields, updates the rest', () async {
      await ctrl().saveVehicle(newVehicle: _thar);
      final thar = snap().editingVehicle!;

      ctrl().backToFleet();
      ctrl().startEditVehicle(thar);
      expect(snap().stage, OnboardingStage.vehicleForm);
      expect(snap().editingVehicle!.id, thar.id);

      final ok = await ctrl().saveVehicle(
        edits: const PartnerVehicleEditDraft(
            color: 'Midnight Black', city: 'Noida'),
      );

      expect(ok, isTrue);
      final updated = repo.fleet.single;
      expect(updated.color, 'Midnight Black');
      expect(updated.city, 'Noida');
      expect(updated.registrationNumber, 'DL01AB1234');
      expect(updated.vehicleTypeId, 'VT_THAR');
    });

    test('rejected vehicle add surfaces backend error and stays put', () async {
      repo.throwOnNext = DioException(
        requestOptions: RequestOptions(path: '/api/v1/partner/vehicles'),
        type: DioExceptionType.badResponse,
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/v1/partner/vehicles'),
          statusCode: 400,
          data: {
            'success': false,
            'error': {
              'code': 'VALIDATION_FAILED',
              'message': 'registrationNumber must match the plate format.',
            },
          },
        ),
      );

      final ok = await ctrl().saveVehicle(newVehicle: _thar);

      expect(ok, isFalse);
      expect(snap().stage, isNot(OnboardingStage.pricing));
      expect(snap().errorMessage, contains('registrationNumber'));
      expect(repo.fleet, isEmpty);
    });

    test('photo URLs ride along with the vehicle draft', () async {
      await ctrl().saveVehicle(
        newVehicle: const PartnerVehicleDraft(
          vehicleTypeId: 'VT_THAR',
          yearOfManufacture: 2024,
          registrationNumber: 'DL01AB1234',
          color: 'Everest White',
          fuelType: 'DIESEL',
          transmission: 'MANUAL',
          city: 'Delhi NCR',
          photoUrls: [
            'https://cdn.example/ext-1.jpg',
            'https://cdn.example/int-1.jpg',
          ],
        ),
      );

      final wire = repo.payloads.last as Map<String, dynamic>;
      expect(wire['photoUrls'], [
        'https://cdn.example/ext-1.jpg',
        'https://cdn.example/int-1.jpg',
      ]);
    });
  });

  group('pricing flow', () {
    setUp(() async {
      repo.profile = _newPartnerProfile();
      await ctrl().saveProfile(_draft);
      await ctrl().saveVehicle(newVehicle: _thar);
    });

    test('submitTariff records paise ints and moves to review', () async {
      final ok = await ctrl().submitTariff(_tariff);

      expect(ok, isTrue);
      final wire = repo.payloads.last as Map<String, dynamic>;
      expect(wire, {
        'localIncludedKm': 45,
        'localAmountPaise': 300000,
        // The per-km rate is server-derived from these two inputs.
        'fuelPricePerLitre': 95.0,
        'mileageKmPerLitre': 8.0,
      });
      expect(snap().editingVehicleTariffs, hasLength(1));
      expect(
          snap().editingVehicleTariffs.single.status, TariffStatus.pendingReview);
      expect(snap().stage, OnboardingStage.review);
    });
  });

  group('submission for verification', () {
    test('backend refuses with no vehicles: error surfaces, not submitted',
        () async {
      repo.profile = _newPartnerProfile();
      await ctrl().saveProfile(_draft);
      ctrl().goToReview();

      final ok = await ctrl().submitForVerification();

      expect(ok, isFalse);
      expect(snap().submittedForReview, isFalse);
      expect(snap().errorMessage,
          'Add at least one vehicle before submitting for verification.');
      expect(snap().profile!.verificationStatus,
          PartnerVerificationStatus.pendingSubmission);
    });

    test('full happy path: Thar + Scorpio + pricing to SUBMITTED partner',
        () async {
      repo.profile = _newPartnerProfile();
      await ctrl().saveProfile(_draft);
      await ctrl().saveVehicle(newVehicle: _thar);
      await ctrl().submitTariff(_tariff);
      ctrl().backToFleet();
      ctrl().startAddVehicle();
      await ctrl().saveVehicle(newVehicle: _scorpio);
      await ctrl().submitTariff(_tariff);

      final ok = await ctrl().submitForVerification();

      expect(ok, isTrue);
      expect(snap().profile!.verificationStatus,
          PartnerVerificationStatus.submitted);
      expect(snap().profile!.submittedAt, isNotNull);
      expect(snap().submittedForReview, isTrue);
      // After submit the shell returns to the fleet (under review), not a
      // fake "verified" screen.
      expect(snap().stage, OnboardingStage.fleet);
    });
  });

  // The backend gates every /api/v1/partner/* route to driver + fleetOwner.
  // These two wire shapes are what a real session actually receives, and each
  // one must be told apart: 404 is the expected first-run state, 403 is a gate.
  group('backend identity gate', () {
    DioException wireError(int status, String code, String message) =>
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
            statusCode: status,
            data: {
              'success': false,
              'error': {'code': code, 'message': message},
            },
          ),
        );

    test('customer session (403 ROLE_FORBIDDEN) becomes a stated role gate, '
        'not a raw error', () async {
      repo.throwOnNext = wireError(
        403,
        'ROLE_FORBIDDEN',
        'Your role does not have permission to perform this action.',
      );

      await ctrl().refreshProfile();

      expect(snap().roleBlocked, isTrue);
      // A gate is not a failure: nothing should read as a broken request.
      expect(snap().errorMessage, isNull);
      expect(snap().isLoading, isFalse);
      expect(snap().profile, isNull);
    });

    test('unregistered partner (404 NOT_FOUND) is the first-run details step, '
        'never an error', () async {
      repo.throwOnNext = wireError(
        404,
        'NOT_FOUND',
        'No partner profile for this account. Register as a partner first.',
      );

      await ctrl().refreshProfile();

      expect(snap().errorMessage, isNull);
      expect(snap().roleBlocked, isFalse);
      expect(snap().profile, isNull);
      expect(snap().stage, OnboardingStage.profile);
    });

    test('a genuine fault (500) still surfaces as an error', () async {
      repo.throwOnNext = wireError(
        500,
        'INTERNAL_ERROR',
        'Something went wrong on our side.',
      );

      await ctrl().refreshProfile();

      expect(snap().errorMessage, isNotNull);
      expect(snap().roleBlocked, isFalse);
    });

    test('a returning registered partner still lands on their fleet', () async {
      repo.profile = _newPartnerProfile();

      await ctrl().refreshProfile();

      expect(snap().roleBlocked, isFalse);
      expect(snap().errorMessage, isNull);
      expect(snap().stage, OnboardingStage.fleet);
    });
  });
}

PartnerProfile _newPartnerProfile() {
  return PartnerProfile(
    id: 'partner-1',
    companyName: 'Sharma Wedding Fleets',
    contactName: 'Rakesh Sharma',
    baseCity: 'Delhi NCR',
    serviceCities: const ['Delhi NCR'],
    languagesSpoken: const ['Hindi'],
    experienceYears: 7,
    verificationStatus: PartnerVerificationStatus.pendingSubmission,
    submittedAt: null,
    reviewedAt: null,
    decisionReason: null,
  );
}
