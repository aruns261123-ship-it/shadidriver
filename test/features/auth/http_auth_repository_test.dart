import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/config/flavor.dart';
import 'package:shadidriver/core/constants/app_constants.dart';
import 'package:shadidriver/core/logging/logger_impl.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/security/secure_session_storage_impl.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/core/security/session_storage_service.dart';
import 'package:shadidriver/features/auth/data/http_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/account_status.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}

class FakeHttpClientAdapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody jsonResponse(Map<String, dynamic> data,
      {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('HttpAuthRepository Unit Tests', () {
    late InMemorySecureStorage storage;
    late SessionStorageService sessionStorage;
    late FakeHttpClientAdapter adapter;
    late ApiClient apiClient;
    late HttpAuthRepository authRepo;

    setUp(() {
      storage = InMemorySecureStorage();
      sessionStorage = SecureSessionStorageImpl(storage);
      adapter = FakeHttpClientAdapter();

      final dio = Dio()..httpClientAdapter = adapter;
      apiClient = ApiClient(
        config: const EnvironmentConfig(
          flavor: AppFlavor.development,
          appName: 'Test',
          apiBaseUrl: 'https://test-api.shadidriver.in',
          wsBaseUrl: 'wss://test-api.shadidriver.in/ws',
        ),
        logger: AppLoggerImpl(),
        secureStorage: storage,
        dio: dio,
      );

      authRepo = HttpAuthRepository(
        apiClient: apiClient,
        sessionStorage: sessionStorage,
      );
    });

    test('1. requestOtp returns otpSessionId on successful backend response',
        () async {
      adapter.handler = (options) {
        expect(options.path, equals('/auth/otp/request'));
        expect(options.data,
            equals({'phoneNumber': '+919876543210', 'role': 'customer'}));
        return FakeHttpClientAdapter.jsonResponse({
          'otpSessionId': 'sess_test_12345',
        });
      };

      final result = await authRepo.requestOtp(
        phoneNumber: '+919876543210',
        role: UserRole.customer,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals('sess_test_12345'));
    });

    test('2. requestOtp returns failure when server rejects request', () async {
      adapter.handler = (options) {
        return FakeHttpClientAdapter.jsonResponse({
          'error': {
            'code': 'RATE_LIMIT_EXCEEDED',
            'message': 'Too many OTP requests. Please wait 5 minutes.',
          },
        }, statusCode: 429);
      };

      final result = await authRepo.requestOtp(phoneNumber: '+919876543210');

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Too many OTP requests'));
    });

    test(
        '3. verifyOtp parses session, persists tokens, and returns AuthSession',
        () async {
      adapter.handler = (options) {
        expect(options.path, equals('/auth/otp/verify'));
        expect(options.data,
            equals({'otpSessionId': 'sess_test_12345', 'otpCode': '123456'}));
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 'usr_customer_001',
          'phone': '+91 98765 43210',
          'role': 'customer',
          'displayName': 'Aditya Singhal',
          'accountStatus': 'active',
          'issuedAt': '2026-09-17T10:00:00Z',
          'accessToken': 'jwt_access_token_xyz',
          'refreshToken': 'jwt_refresh_token_abc',
        });
      };

      final result = await authRepo.verifyOtp(
        otpSessionId: 'sess_test_12345',
        otpCode: '123456',
      );

      expect(result.isSuccess, isTrue);
      final session = result.dataOrNull!;
      expect(session.userId, equals('usr_customer_001'));
      expect(session.role, equals(UserRole.customer));
      expect(session.accountStatus, equals(AccountStatus.active));
      expect(session.displayName, equals('Aditya Singhal'));

      // Verify hardware-backed storage was written via SecureSessionStorageImpl
      expect(await storage.read(AppConstants.keyAccessToken),
          equals('jwt_access_token_xyz'));
      expect(await storage.read(AppConstants.keyRefreshToken),
          equals('jwt_refresh_token_abc'));
      expect(await storage.read(AppConstants.keyUserId),
          equals('usr_customer_001'));
      expect(await storage.read(AppConstants.keyUserRole), equals('customer'));
    });

    test('4. restoreSession returns session when valid stored session exists',
        () async {
      await storage.write(AppConstants.keyAccessToken, 'stored_token_abc');
      await storage.write(AppConstants.keyRefreshToken, 'stored_refresh_abc');
      await storage.write(AppConstants.keyUserId, 'usr_driver_002');
      await storage.write(AppConstants.keyUserRole, 'driver');
      await storage.write(AppConstants.keyPhone, '+91 98100 00002');
      await storage.write(AppConstants.keyAccountStatus, 'active');
      await storage.write(AppConstants.keyDisplayName, 'Rajesh Kumar');
      await storage.write(
          AppConstants.keySessionIssued, DateTime.now().toIso8601String());

      final result = await authRepo.restoreSession();

      expect(result.isSuccess, isTrue);
      final session = result.dataOrNull!;
      expect(session.userId, equals('usr_driver_002'));
      expect(session.role, equals(UserRole.driver));
      expect(session.displayName, equals('Rajesh Kumar'));
      expect(session.isAuthenticated, isTrue);
    });

    test('5. restoreSession returns null when storage has no credentials',
        () async {
      final result = await authRepo.restoreSession();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
    });

    test('6. signOut revokes session remotely and clears session storage',
        () async {
      await storage.write(AppConstants.keyAccessToken, 'token_to_clear');
      await storage.write(AppConstants.keyUserId, 'usr_to_clear');

      adapter.handler = (options) {
        expect(options.path, equals('/auth/logout'));
        return FakeHttpClientAdapter.jsonResponse({'success': true});
      };

      final result = await authRepo.signOut();

      expect(result.isSuccess, isTrue);
      expect(await storage.read(AppConstants.keyAccessToken), isNull);
      expect(await storage.read(AppConstants.keyUserId), isNull);
    });

    test('7. refreshSession fetches new tokens and updates storage', () async {
      await storage.write(
          AppConstants.keyRefreshToken, 'existing_refresh_token');

      adapter.handler = (options) {
        expect(options.path, equals('/auth/refresh'));
        expect(
            options.data, equals({'refreshToken': 'existing_refresh_token'}));
        return FakeHttpClientAdapter.jsonResponse({
          'userId': 'usr_customer_001',
          'phone': '+91 98765 43210',
          'role': 'customer',
          'displayName': 'Aditya Singhal',
          'accountStatus': 'active',
          'issuedAt': '2026-09-17T10:00:00Z',
          'accessToken': 'new_jwt_access_token',
          'refreshToken': 'new_jwt_refresh_token',
        });
      };

      final result = await authRepo.refreshSession();

      expect(result.isSuccess, isTrue);
      expect(await storage.read(AppConstants.keyAccessToken),
          equals('new_jwt_access_token'));
      expect(await storage.read(AppConstants.keyRefreshToken),
          equals('new_jwt_refresh_token'));
    });
  });
}
