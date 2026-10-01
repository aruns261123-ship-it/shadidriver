import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/partner/data/partner_api_repository.dart';
import 'package:shadidriver/features/partner/domain/entities/partner_enums.dart';
import 'package:shadidriver/features/partner/domain/repositories/partner_repository.dart';

class _InMemoryStorage implements SecureStorageService {
  final Map<String, String> _data = {};
  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);
  @override
  Future<void> delete(String key) async => _data.remove(key);
  @override
  Future<void> deleteAll() async => _data.clear();
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

class _SilentLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Resolves every request from [routes] and records method+path+body so tests
/// can assert the exact wire contract the NestJS backend expects.
class _RecordingStub extends Interceptor {
  final Map<String, dynamic> body;
  final List<String> methods = [];
  final List<String> paths = [];
  final List<Object?> bodies = [];
  DioException? throwOnNext;

  _RecordingStub(this.body);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    methods.add(options.method);
    paths.add(options.path);
    bodies.add(options.data);
    final fail = throwOnNext;
    if (fail != null) {
      throwOnNext = null;
      handler.reject(fail);
      return;
    }
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: options.method == 'POST' ? 201 : 200,
        data: body,
      ),
    );
  }
}

const _config = EnvironmentConfig(
  flavor: AppFlavor.development,
  appName: 'ShadiDriver Test',
  apiBaseUrl: 'http://localhost:3000',
  wsBaseUrl: 'ws://localhost:3000',
  useMockData: false,
);

/// canonical viewProfile payload — snake_case, exactly what
/// PartnerService.viewProfile emits.
Map<String, dynamic> profileBody({Map<String, dynamic>? data}) => {
      'success': true,
      'data': data ??
          {
            'id': 'partner-1',
            'company_name': 'Sharma Wedding Fleets',
            'contact_name': 'Rakesh Sharma',
            'base_city': 'Delhi NCR',
            'service_cities': ['Delhi NCR', 'Jaipur'],
            'languages_spoken': ['Hindi', 'English'],
            'experience_years': 7,
            'verification_status': 'PENDING_SUBMISSION',
            'submitted_at': null,
            'reviewed_at': null,
            'decision_reason': null,
            'is_verified': false,
            'can_receive_bookings': false,
            'vehicle_count': 2,
            'document_count': 6,
          },
    };

/// canonical viewVehicle payload — snake_case per viewVehicle.
Map<String, dynamic> vehicleJson({
  String id = 'vh-1',
  String? displayName,
  String status = 'PENDING_SUBMISSION',
  List<Map<String, dynamic>> documents = const [],
}) =>
    {
      'id': id,
      'fleet_code': 'SD-VH-0007',
      'vehicle_type_id': 'VT_THAR',
      'display_name': displayName,
      'seating_capacity': 5,
      'vehicle_class': 'LUXURY_SUV',
      'year': 2024,
      'registration_number': 'DL01AB1234',
      'color': 'Everest White',
      'fuel_type': 'DIESEL',
      'transmission': 'MANUAL',
      'city': 'Delhi NCR',
      'service_areas': ['South Delhi'],
      'amenities': ['AC', 'Floral Decoration'],
      'photo_urls': ['https://cdn.example/thar-1.jpg'],
      'is_active': true,
      'is_available': true,
      'is_bookable': false,
      'verification_status': status,
      'documents': documents,
    };

void main() {
  _RecordingStub stub(Map<String, dynamic> body) => _RecordingStub(body);

  PartnerApiRepository buildRepo(_RecordingStub interceptor) {
    final dio = Dio()..interceptors.add(interceptor);
    return PartnerApiRepository(
      ApiClient(
        config: _config,
        logger: _SilentLogger(),
        secureStorage: _InMemoryStorage(),
        dio: dio,
      ),
    );
  }

  group('partner registration wire contract', () {
    test('POSTs camelCase RegisterPartnerDto to /partner/registration',
        () async {
      final s = stub(profileBody());
      final repo = buildRepo(s);

      final result = await repo.register(const PartnerRegistrationDraft(
        companyName: 'Sharma Wedding Fleets',
        baseCity: 'Delhi NCR',
        contactName: 'Rakesh Sharma',
        serviceCities: ['Delhi NCR', 'Jaipur'],
        languagesSpoken: ['Hindi', 'English'],
        experienceYears: 7,
        licenseNumber: 'DL-1420190004567',
        emergencyContactName: 'Sunita Sharma',
        emergencyContactPhone: '+919876543210',
      ));

      expect(result.isSuccess, isTrue);
      expect(s.methods, ['POST']);
      expect(s.paths.single, '/api/v1/partner/registration');
      expect(s.bodies.single, {
        'companyName': 'Sharma Wedding Fleets',
        'baseCity': 'Delhi NCR',
        'contactName': 'Rakesh Sharma',
        'serviceCities': ['Delhi NCR', 'Jaipur'],
        'languagesSpoken': ['Hindi', 'English'],
        'experienceYears': 7,
        'licenseNumber': 'DL-1420190004567',
        'emergencyContactName': 'Sunita Sharma',
        'emergencyContactPhone': '+919876543210',
      });
    });

    test('maps the snake_case viewProfile back onto the entity', () async {
      final repo = buildRepo(stub(profileBody()));
      final profile = (await repo.getProfile()).dataOrNull!;

      expect(profile.id, 'partner-1');
      expect(profile.companyName, 'Sharma Wedding Fleets');
      expect(profile.baseCity, 'Delhi NCR');
      expect(profile.serviceCities, ['Delhi NCR', 'Jaipur']);
      expect(profile.languagesSpoken, ['Hindi', 'English']);
      expect(profile.experienceYears, 7);
      expect(profile.verificationStatus,
          PartnerVerificationStatus.pendingSubmission);
      expect(profile.vehicleCount, 2);
      expect(profile.documentCount, 6);
    });

    test('profile updates go through PATCH, not POST', () async {
      final s = stub(profileBody());
      final repo = buildRepo(s);

      await repo.updateProfile(const PartnerRegistrationDraft(
        companyName: 'Sharma Wedding Fleets',
        baseCity: 'Gurugram',
      ));

      expect(s.methods.single, 'PATCH');
      expect(s.paths.single, '/api/v1/partner/profile');
      expect(s.bodies.single, {
        'companyName': 'Sharma Wedding Fleets',
        'baseCity': 'Gurugram',
      });
    });

    test('unknown verification status degrades to pending, never throws',
        () async {
      final body = profileBody(
        data: {...profileBody()['data'] as Map<String, dynamic>,
          'verification_status': 'SOMETHING_NEW'},
      );
      final repo = buildRepo(stub(body));
      final profile = (await repo.getProfile()).dataOrNull!;
      expect(profile.verificationStatus,
          PartnerVerificationStatus.pendingSubmission);
    });
  });

  group('fleet wire contract', () {
    test('listFleet reads items[]+total and maps every vehicle field',
        () async {
      final s = stub({
        'success': true,
        'data': {
          'items': [
            vehicleJson(status: 'APPROVED'),
            vehicleJson(id: 'vh-2', displayName: 'Mahindra Scorpio',
                status: 'ACTION_REQUIRED', documents: [
              {
                'type': 'COMMERCIAL_INSURANCE',
                'status': 'ACTION_REQUIRED',
                'expires_at': '2026-12-01T00:00:00.000Z',
              },
            ]),
          ],
          'total': 2,
        },
      });
      final repo = buildRepo(s);

      final fleet = (await repo.listFleet()).dataOrNull!;

      expect(s.methods.single, 'GET');
      expect(s.paths.single, '/api/v1/partner/vehicles');
      expect(fleet.total, 2);
      expect(fleet.items, hasLength(2));

      final thar = fleet.items[0];
      expect(thar.fleetCode, 'SD-VH-0007');
      expect(thar.vehicleTypeId, 'VT_THAR');
      expect(thar.seatingCapacity, 5);
      expect(thar.year, 2024);
      expect(thar.verificationStatus, PartnerVerificationStatus.approved);
      expect(thar.isBookable, isFalse);
      expect(thar.maskedRegistration, '•••• 1234');

      final scorpio = fleet.items[1];
      expect(scorpio.displayName, 'Mahindra Scorpio');
      expect(scorpio.verificationStatus,
          PartnerVerificationStatus.actionRequired);
      expect(scorpio.documents.single.type, 'COMMERCIAL_INSURANCE');
      expect(scorpio.documents.single.status,
          PartnerVerificationStatus.actionRequired);
      expect(scorpio.documents.single.expiresAt, isNotNull);
      expect(scorpio.hasPendingDocuments, isFalse);
    });

    test('addVehicle POSTs the AddVehicleDto camelCase shape', () async {
      final s = stub({'success': true, 'data': vehicleJson()});
      final repo = buildRepo(s);

      final result = await repo.addVehicle(const PartnerVehicleDraft(
        vehicleTypeId: 'VT_THAR',
        yearOfManufacture: 2024,
        registrationNumber: 'DL01AB1234',
        color: 'Everest White',
        fuelType: 'DIESEL',
        transmission: 'MANUAL',
        city: 'Delhi NCR',
        serviceAreas: ['South Delhi'],
        amenities: ['AC'],
        photoUrls: ['https://cdn.example/thar-1.jpg'],
      ));

      expect(result.isSuccess, isTrue);
      expect(s.methods.single, 'POST');
      expect(s.paths.single, '/api/v1/partner/vehicles');
      expect(s.bodies.single, {
        'vehicleTypeId': 'VT_THAR',
        'yearOfManufacture': 2024,
        'registrationNumber': 'DL01AB1234',
        'color': 'Everest White',
        'fuelType': 'DIESEL',
        'transmission': 'MANUAL',
        'city': 'Delhi NCR',
        'serviceAreas': ['South Delhi'],
        'amenities': ['AC'],
        'photoUrls': ['https://cdn.example/thar-1.jpg'],
      });
    });

    test('updateVehicle never sends identity fields the backend forbids',
        () async {
      final s = stub({'success': true, 'data': vehicleJson()});
      final repo = buildRepo(s);

      await repo.updateVehicle('vh-1', const PartnerVehicleEditDraft(
        color: 'Midnight Black',
        city: 'Noida',
      ));

      expect(s.methods.single, 'PUT');
      expect(s.paths.single, '/api/v1/partner/vehicles/vh-1');
      final wire = s.bodies.single as Map<String, dynamic>;
      expect(wire, {'color': 'Midnight Black', 'city': 'Noida'});
      expect(wire.keys, isNot(contains('vehicleTypeId')));
      expect(wire.keys, isNot(contains('registrationNumber')));
    });

    test('removeVehicle DELETEs the vehicle resource', () async {
      final s = stub({'success': true, 'data': null});
      final repo = buildRepo(s);

      final result = await repo.removeVehicle('vh-1');

      expect(result.isSuccess, isTrue);
      expect(s.methods.single, 'DELETE');
      expect(s.paths.single, '/api/v1/partner/vehicles/vh-1');
    });
  });

  group('document + pricing wire contract', () {
    test('addVehicleDocument POSTs the reference, not bytes', () async {
      final s = stub({'success': true, 'data': null});
      final repo = buildRepo(s);

      final result = await repo.addVehicleDocument(
        'vh-1',
        VehicleDocumentDraft(
          documentType: 'REGISTRATION_CERTIFICATE',
          storagePath: 'partner-docs/vh-1/rc.pdf',
          mimeType: 'application/pdf',
          documentNumber: 'RC-DL-2024-778899',
          expiryDate: DateTime(2036, 1, 31),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(s.methods.single, 'POST');
      expect(s.paths.single, '/api/v1/partner/vehicles/vh-1/documents');
      expect(s.bodies.single, {
        'documentType': 'REGISTRATION_CERTIFICATE',
        'storagePath': 'partner-docs/vh-1/rc.pdf',
        'mimeType': 'application/pdf',
        'documentNumber': 'RC-DL-2024-778899',
        'expiryDate': '2036-01-31',
      });
    });

    test('listTariffs maps the version history (paise stay strings)',
        () async {
      final s = stub({
        'success': true,
        'data': {
          'vehicle_id': 'vh-1',
          'items': [
            {
              'id': 'tar-1',
              'vehicle_id': 'vh-1',
              'version': 1,
              'currency': 'INR',
              'local_included_km': 45,
              'local_amount_paise': '300000',
              'per_km_paise': '1400',
              'hourly_paise': '25000',
              'extra_hour_paise': '25000',
              'full_day_paise': '1500000',
              'overnight_paise': null,
              'outstation_per_day_paise': '1200000',
              'outstation_per_km_paise': '1600',
              'status': 'PENDING_REVIEW',
              'submitted_at': '2026-09-20T10:00:00.000Z',
              'reviewed_at': null,
              'decision_reason': null,
              'effective_from': null,
            },
          ],
          'live_version': null,
        },
      });
      final repo = buildRepo(s);

      final tariffs = (await repo.listTariffs('vh-1')).dataOrNull!;

      expect(s.methods.single, 'GET');
      expect(s.paths.single, '/api/v1/partner/vehicles/vh-1/pricing');
      expect(tariffs, hasLength(1));
      final t = tariffs.single;
      expect(t.version, 1);
      expect(t.localIncludedKm, 45);
      // Paise integers arrive as strings and stay strings — precision-safe.
      expect(t.localAmountPaise, '300000');
      expect(t.perKmPaise, '1400');
      expect(t.outstationPerDayPaise, '1200000');
      expect(t.status, TariffStatus.pendingReview);
    });

    test('submitTariff POSTs the SubmitVehiclePricingDto paise integers',
        () async {
      final s = stub({
        'success': true,
        'data': {
          'id': 'tar-2',
          'vehicle_id': 'vh-1',
          'version': 2,
          'currency': 'INR',
          'local_included_km': 45,
          'local_amount_paise': '300000',
          'per_km_paise': '1400',
          'status': 'PENDING_REVIEW',
          'submitted_at': '2026-09-27T10:00:00.000Z',
        },
      });
      final repo = buildRepo(s);

      final result = await repo.submitTariff(
        'vh-1',
        const VehicleTariffDraft(
          localIncludedKm: 45,
          localAmountPaise: 300000,
          fuelPricePerLitre: 95,
          mileageKmPerLitre: 8,
          hourlyPaise: 25000,
          fullDayPaise: 1500000,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(s.methods.single, 'POST');
      expect(s.paths.single, '/api/v1/partner/vehicles/vh-1/pricing');
      // Exact DTO shape: required inputs (fuel + mileage drive the server-
      // derived rate) + optional additions, all ints.
      expect(s.bodies.single, {
        'localIncludedKm': 45,
        'localAmountPaise': 300000,
        'fuelPricePerLitre': 95.0,
        'mileageKmPerLitre': 8.0,
        'hourlyPaise': 25000,
        'fullDayPaise': 1500000,
      });
    });
  });

  group('submit for verification', () {
    test('POSTs /partner/submit and returns the SUBMITTED profile', () async {
      final s = stub(profileBody(
        data: {...profileBody()['data'] as Map<String, dynamic>,
          'verification_status': 'SUBMITTED',
          'submitted_at': '2026-09-27T10:00:00.000Z'},
      ));
      final repo = buildRepo(s);

      final result = await repo.submitForVerification();

      expect(s.methods.single, 'POST');
      expect(s.paths.single, '/api/v1/partner/submit');
      expect(s.bodies.single, isNull);
      expect(result.dataOrNull!.verificationStatus,
          PartnerVerificationStatus.submitted);
      expect(result.dataOrNull!.submittedAt, isNotNull);
    });
  });

  group('backend validation error mapping', () {
    DioException backendError(int status, Map<String, dynamic> error) =>
        DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/vehicles'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/v1/partner/vehicles'),
            statusCode: status,
            data: {'success': false, 'error': error},
          ),
        );

    test('service 400 message becomes ValidationFailure with backend text',
        () async {
      final s = stub(profileBody())..throwOnNext = backendError(400, {
        'code': 'VALIDATION_FAILED',
        'message': 'Add at least one vehicle before submitting for verification.',
      });
      final repo = buildRepo(s);

      final result = await repo.submitForVerification();

      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure, isA<ValidationFailure>());
      expect(
        failure.message,
        'Add at least one vehicle before submitting for verification.',
      );
    });

    test('class-validator details map to per-field errors', () async {
      final s = stub(profileBody())..throwOnNext = backendError(400, {
        'code': 'VALIDATION_FAILED',
        'message': 'Bad Request',
        'details': {
          'validation': [
            'registrationNumber registrationNumber must match the plate format',
            'yearOfManufacture yearOfManufacture must not be greater than 2100',
          ],
        },
      });
      final repo = buildRepo(s);

      final result = await repo.addVehicle(const PartnerVehicleDraft(
        vehicleTypeId: 'VT_THAR',
        yearOfManufacture: 3000,
        registrationNumber: 'nope',
        color: 'Black',
        fuelType: 'DIESEL',
        transmission: 'MANUAL',
        city: 'Delhi NCR',
      ));

      final failure = result.failureOrNull!;
      expect(failure, isA<ValidationFailure>());
      final fields =
          (failure as ValidationFailure).fieldErrors ?? const {};
      expect(fields.keys, containsAll(['registrationNumber',
          'yearOfManufacture']));
    });

    test('401 maps to UnauthorizedFailure so the UI can re-auth', () async {
      final s = stub(profileBody())..throwOnNext = backendError(401, {
        'code': 'AUTH_INVALID_TOKEN',
        'message': 'Unauthorized',
      });
      final repo = buildRepo(s);

      final result = await repo.getProfile();

      expect(result.failureOrNull, isA<UnauthorizedFailure>());
    });

    test('transport failure maps to NetworkFailure', () async {
      final s = stub(profileBody())
        ..throwOnNext = DioException(
          requestOptions: RequestOptions(path: '/api/v1/partner/profile'),
          type: DioExceptionType.connectionError,
        );
      final repo = buildRepo(s);

      final result = await repo.getProfile();

      expect(result.failureOrNull, isA<NetworkFailure>());
    });
  });
}
