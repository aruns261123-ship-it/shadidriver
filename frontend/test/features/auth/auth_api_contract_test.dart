import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/network/api_response.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/auth/data/auth_api_repository.dart';

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

/// Captures the outgoing request and short-circuits with [responseBody].
class _CapturingInterceptor extends Interceptor {
  RequestOptions? lastRequest;
  final Map<String, dynamic> responseBody;

  _CapturingInterceptor(this.responseBody);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    lastRequest = options;
    handler.resolve(
      Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
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

void main() {
  late InMemorySecureStorage storage;
  late _CapturingInterceptor interceptor;
  late AuthApiRepository repo;

  AuthApiRepository buildRepo(Map<String, dynamic> responseBody) {
    interceptor = _CapturingInterceptor(responseBody);
    final dio = Dio()..interceptors.add(interceptor);
    final client = ApiClient(
      config: _config,
      logger: SilentTestLogger(),
      secureStorage: storage,
      dio: dio,
    );
    return AuthApiRepository(client, storage);
  }

  setUp(() {
    storage = InMemorySecureStorage();
  });

  group('AuthApiRepository request serialization', () {
    test('signUp sends camelCase phoneNumber/displayName and no snake_case keys', () async {
      repo = buildRepo({
        'success': true,
        'data': {'session_id': 'sess-1', 'expires_in_seconds': 300, 'next_step': 'VERIFY_OTP'},
      });

      final result = await repo.signUp(
        phoneNumber: '9876543210',
        displayName: 'Aarav Sharma',
      );

      expect(result.isSuccess, isTrue);
      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['phoneNumber'], '+919876543210');
      expect(body['displayName'], 'Aarav Sharma');
      expect(body['role'], 'customer');
      expect(body.containsKey('phone_number'), isFalse);
      expect(body.containsKey('display_name'), isFalse);
      // Values MUST be JSON strings, never integers.
      expect(body['phoneNumber'], isA<String>());
      expect(body['displayName'], isA<String>());
    });

    test('signUp normalizes a trunk-0 / formatted number to +91XXXXXXXXXX', () async {
      repo = buildRepo({
        'success': true,
        'data': {'session_id': 'sess-1', 'expires_in_seconds': 300},
      });

      await repo.signUp(phoneNumber: '098765 43210', displayName: 'Aarav');

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['phoneNumber'], '+919876543210');
    });

    test('signUp rejects an invalid phone before any request is sent', () async {
      repo = buildRepo({'success': true, 'data': {}});

      final result = await repo.signUp(
        phoneNumber: '12345',
        displayName: 'Aarav Sharma',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(result.failureOrNull!.message, 'Enter a valid mobile number.');
      expect(interceptor.lastRequest, isNull);
    });

    test('signUp rejects a too-short display name before any request', () async {
      repo = buildRepo({'success': true, 'data': {}});

      final result = await repo.signUp(
        phoneNumber: '9876543210',
        displayName: 'A',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull!.message, 'Name must be at least 2 characters.');
      expect(interceptor.lastRequest, isNull);
    });

    test('requestOtp sends camelCase phoneNumber and purpose', () async {
      repo = buildRepo({
        'success': true,
        'data': {'session_id': 'sess-1', 'expires_in_seconds': 300},
      });

      await repo.requestOtp(phoneNumber: '9810000001');

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['phoneNumber'], '+919810000001');
      expect(body['purpose'], 'LOGIN');
      expect(body.containsKey('phone_number'), isFalse);
      expect(interceptor.lastRequest!.path, endsWith('/auth/otp/request'));
    });

    test('verifyOtp sends camelCase sessionId and otpCode', () async {
      repo = buildRepo({
        'success': true,
        'data': {
          'access_token': 'ey.token',
          'refresh_token': 'refresh.token',
          'user': {'id': 'u1', 'role': 'customer', 'account_status': 'ACTIVE'},
        },
      });

      await repo.verifyOtp(otpSessionId: 'sess-1', otpCode: '849201');

      final body = interceptor.lastRequest!.data as Map<String, dynamic>;
      expect(body['sessionId'], 'sess-1');
      expect(body['otpCode'], '849201');
      expect(body.containsKey('session_id'), isFalse);
      expect(body.containsKey('otp_code'), isFalse);
    });
  });

  group('mapDioError validation mapping', () {
    DioException badRequest(Map<String, dynamic> error) => DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/signup'),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/api/v1/auth/signup'),
        statusCode: 400,
        data: {'success': false, 'error': error},
      ),
    );

    test('surfaces the unknown property for contract drift (phone_number)', () {
      final failure = mapDioError(
        badRequest({
          'code': 'VALIDATION_FAILED',
          'message': [
            'property phone_number should not exist',
            'property display_name should not exist',
          ],
          'details': {
            'validation': [
              'property phone_number should not exist',
              'property display_name should not exist',
            ],
          },
        }),
      );

      expect(failure, isA<ValidationFailure>());
      final validation = failure as ValidationFailure;
      expect(validation.fieldErrors, isNotNull);
      expect(validation.fieldErrors!.keys, containsAll(['phone_number', 'display_name']));
      expect(validation.message, contains('unsupported field'));
    });

    test('maps a phoneNumber field error to a friendly message', () {
      final failure = mapDioError(
        badRequest({
          'code': 'VALIDATION_FAILED',
          'message': 'phoneNumber must be a valid Indian mobile (+91 followed by 10 digits).',
          'details': {
            'validation': [
              'phoneNumber must be an E.164 string like +919876543210 (leading +, no spaces).',
            ],
          },
        }),
      );

      expect(failure.message, 'Enter a valid mobile number.');
      expect((failure as ValidationFailure).fieldErrors!.keys, contains('phoneNumber'));
    });

    test('maps a displayName length error to a friendly message', () {
      final failure = mapDioError(
        badRequest({
          'code': 'VALIDATION_FAILED',
          'message': 'displayName must be longer than or equal to 2 characters',
          'details': {
            'validation': ['displayName must be longer than or equal to 2 characters'],
          },
        }),
      );

      expect(failure.message, 'Name must be at least 2 characters.');
    });

    test('keeps the raw backend message when there are no validation details', () {
      final failure = mapDioError(
        badRequest({
          'code': 'VALIDATION_FAILED',
          'message': 'Something else went wrong.',
        }),
      );

      expect(failure.message, 'Something else went wrong.');
    });
  });
}
