import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/bookings/data/booking_api_repository.dart';
import 'package:shadidriver/features/bookings/data/dto/submit_booking_dto.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/policies/booking_location_rules.dart';
import 'package:shadidriver/features/bookings/domain/policies/service_category_policy.dart';

class InMemorySecureStorage implements SecureStorageService {
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

class SilentTestLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}
  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}
}

/// Captures the outgoing request and answers with [response] (or a Dio error
/// when [errorStatus] is set), so the serialized wire payload can be asserted
/// without a server.
class _CapturingInterceptor extends Interceptor {
  RequestOptions? lastRequest;
  final Map<String, dynamic> responseBody;
  final int? errorStatus;
  int requestCount = 0;

  _CapturingInterceptor(this.responseBody, {this.errorStatus});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    requestCount++;
    if (errorStatus != null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: options,
            statusCode: errorStatus,
            data: responseBody,
          ),
        ),
      );
      return;
    }
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 201,
        data: responseBody,
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

const _successBody = {
  'success': true,
  'data': {
    'booking': {
      'id': 'b-1',
      'referenceCode': 'SD-2026-0101',
      'status': 'REQUESTED',
      'submittedAt': '2026-09-25T07:00:00.000Z',
      'estimatedTotalPaise': '3955000',
      'advanceTokenPaise': '988750',
      'advanceTokenLabel': 'Advance Token (25%)',
    },
    'idempotent_replay': false,
  },
};

BookingSubmissionRequest validRequest({
  String pickupAddress = 'Sector 15, Gurugram',
  String destinationAddress = 'The Leela Palace, Chanakyapuri, New Delhi',
}) => BookingSubmissionRequest(
  draftId: 'draft-1',
  vehicleId: '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e',
  vehicleName: 'Mercedes-Benz S-Class',
  vehicleClass: 'Ultra Luxury',
  chauffeurId: 'de88a65c-3da5-4cae-9636-328891664f07',
  ceremonyType: 'Baraat',
  ceremonialAttire: 'Safa & Bandhgala',
  specialInstructions: 'Royal entrance',
  serviceStartDateTime: DateTime.utc(2026, 11, 20, 10, 30),
  serviceEndDateTime: DateTime.utc(2026, 11, 20, 18, 30),
  city: 'Delhi NCR',
  pickupAddress: pickupAddress,
  destinationAddress: destinationAddress,
  venueName: 'The Leela Palace',
  primaryContactName: 'Aarav Sharma',
  primaryContactPhone: '+919810000001',
  passengerCount: 4,
  basePricePaise: 3500000,
  estimatedTotalPaise: 3955000,
  advanceTokenPaise: 988750,
  idempotencyKey: 'bk-test-key-0001',
);

void main() {
  late InMemorySecureStorage storage;
  late _CapturingInterceptor interceptor;

  BookingApiRepository buildRepo(
    Map<String, dynamic> responseBody, {
    int? errorStatus,
  }) {
    interceptor = _CapturingInterceptor(responseBody, errorStatus: errorStatus);
    final dio = Dio()..interceptors.add(interceptor);
    final client = ApiClient(
      config: _config,
      logger: SilentTestLogger(),
      secureStorage: storage,
      dio: dio,
    );
    return BookingApiRepository(client);
  }

  setUp(() {
    storage = InMemorySecureStorage();
  });

  group('POST /api/v1/bookings request serialization', () {
    test('sends only fields the backend SubmitBookingDto declares', () async {
      final repo = buildRepo(_successBody);
      final result = await repo.submitBooking(validRequest());

      expect(result.isSuccess, isTrue);
      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      for (final key in body.keys) {
        expect(
          SubmitBookingDto.contractFields,
          contains(key),
          reason: '$key is not declared on the backend DTO; '
              'forbidNonWhitelisted would reject it',
        );
      }
      for (final key in SubmitBookingDto.requiredContractFields) {
        expect(body.containsKey(key), isTrue, reason: '$key is required');
      }
    });

    test('posts to the documented endpoint with an Idempotency-Key header',
        () async {
      final repo = buildRepo(_successBody);
      await repo.submitBooking(validRequest());

      final request = interceptor.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/bookings');
      expect(request.headers['Idempotency-Key'], 'bk-test-key-0001');
      // The idempotency token must never travel in the body.
      expect(
        (request.data as Map<String, dynamic>).containsKey('idempotencyKey'),
        isFalse,
      );
    });

    test('serializes the canonical location field names', () async {
      final repo = buildRepo(_successBody);
      await repo.submitBooking(validRequest());

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['pickupAddress'], 'Sector 15, Gurugram');
      expect(
        body['destinationAddress'],
        'The Leela Palace, Chanakyapuri, New Delhi',
      );
      // No snake_case aliases, no invented compatibility fields.
      expect(body.containsKey('pickup_address'), isFalse);
      expect(body.containsKey('pickup_location'), isFalse);
      expect(body.containsKey('destination'), isFalse);
      expect(body.containsKey('pickup'), isFalse);
      expect(body.containsKey('pickup_coordinates'), isFalse);
    });

    test('sends no field the backend does not declare', () async {
      final repo = buildRepo(_successBody);
      await repo.submitBooking(validRequest());

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('draftId'), isFalse);
      expect(body.containsKey('vehicleId'), isFalse);
      expect(body.containsKey('chauffeurId'), isFalse);
      expect(body.containsKey('basePricePaise'), isFalse);
      expect(body.containsKey('estimatedTotalPaise'), isFalse);
      expect(body.containsKey('landmark'), isFalse);
    });

    test('maps the ceremony onto a seeded service category', () async {
      final repo = buildRepo(_successBody);
      await repo.submitBooking(validRequest());

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['serviceCategoryId'], ServiceCategoryPolicy.baraat);
      expect(body['vehicleTypeId'], '661bfb4b-4ac7-44b2-9b8b-76e7a29dd66e');
    });
  });

  group('client-side parity with the backend address rule', () {
    test('rejects a 4-character pickup address before any request', () async {
      final repo = buildRepo(_successBody);
      final result = await repo.submitBooking(
        validRequest(pickupAddress: 'Home'),
      );

      // The request never leaves the device, so the server can never answer
      // with "pickupAddress must be longer than or equal to 5 characters".
      expect(interceptor.requestCount, 0);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, contains('Pickup address'));
    });

    test('accepts an address at exactly the server minimum length', () {
      expect(BookingLocationRules.isAddressValid('Delhi'), isTrue);
      expect(BookingLocationRules.addressError('Delhi', label: 'x'), isNull);
      expect(BookingLocationRules.isAddressValid('Hom'), isFalse);
    });

    test('the domain request is invalid for a short address', () {
      final request = validRequest(destinationAddress: 'Taj');
      expect(request.isValid, isFalse);
      expect(request.validationMessage, contains('destination address'));
    });
  });

  group('server validation errors are reported honestly', () {
    test('a length violation on a SUPPORTED field is not called drift',
        () async {
      // Captured verbatim from the running backend for a 4-character address.
      final repo = buildRepo({
        'success': false,
        'error': {
          'code': 'VALIDATION_FAILED',
          'message':
              'pickupAddress must be longer than or equal to 5 characters; '
              'destinationAddress must be longer than or equal to 5 characters',
          'details': {
            'validation': [
              'pickupAddress must be longer than or equal to 5 characters',
              'destinationAddress must be longer than or equal to 5 characters',
            ],
          },
        },
      }, errorStatus: 400);

      final result = await repo.submitBooking(validRequest());
      expect(result.isFailure, isTrue);
      final failure = result.failureOrNull!;
      expect(failure, isA<ValidationFailure>());

      final message = failure.message;
      expect(
        message,
        isNot(contains('unsupported field')),
        reason: 'the backend DOES support pickupAddress/destinationAddress',
      );
      expect(message, contains('Pickup address'));
      expect(message, contains('5 characters'));
      expect(
        (failure as ValidationFailure).fieldErrors!.keys,
        containsAll(['pickupAddress', 'destinationAddress']),
      );
    });

    test('a genuinely unknown field still reports contract drift', () async {
      final repo = buildRepo({
        'success': false,
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'property pickup_address should not exist',
          'details': {
            'validation': ['property pickup_address should not exist'],
          },
        },
      }, errorStatus: 400);

      final result = await repo.submitBooking(validRequest());
      final message = result.failureOrNull!.message;
      expect(message, contains('unsupported field'));
      expect(message, contains('pickup_address'));
    });

    test('a server business rejection passes through unchanged', () async {
      final repo = buildRepo({
        'success': false,
        'error': {
          'code': 'NOT_FOUND',
          'message': 'Vehicle type not found.',
        },
      }, errorStatus: 404);

      final result = await repo.submitBooking(validRequest());
      expect(result.failureOrNull!.message, 'Vehicle type not found.');
    });
  });
}
