// ignore_for_file: prefer_initializing_formals

import 'package:dio/dio.dart';

import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/interceptors/error_interceptor.dart';
import '../../../core/result/result.dart';
import '../../../core/security/session_storage_service.dart';
import '../domain/entities/account_status.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user_role.dart';
import '../domain/repositories/auth_repository.dart';

/// Production HTTP implementation of [AuthRepository].
///
/// Talks to the backend's `/auth/*` endpoints (see docs/API_CONTRACTS.md).
/// Every method follows the same shape: call the API, map success payloads
/// to domain entities, map [DioException] to [AppFailure] via
/// [NetworkErrorMapper], and never let a raw exception escape this class.
///
/// This is the reference pattern for every other Http*Repository in the
/// app — copy this file's structure (constructor, try/catch shape, DTO
/// mapping) when implementing BookingRepository, DriverRepository, etc.
class HttpAuthRepository implements AuthRepository {
  final ApiClient _apiClient;
  final SessionStorageService _sessionStorage;

  const HttpAuthRepository({
    required ApiClient apiClient,
    required SessionStorageService sessionStorage,
  })  : _apiClient = apiClient,
        _sessionStorage = sessionStorage;

  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    UserRole? role,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/request',
        data: {
          'phoneNumber': phoneNumber,
          if (role != null) 'role': role.storageKey,
        },
      );

      final sessionId = response.data?['otpSessionId'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        return const Result.failure(
          UnknownFailure('OTP session could not be created. Please retry.'),
        );
      }
      return Result.success(sessionId);
    } on DioException catch (e) {
      return Result.failure(NetworkErrorMapper.map(e));
    } catch (e) {
      return Result.failure(UnknownFailure('Failed to request OTP.', null, e));
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/otp/verify',
        data: {'otpSessionId': otpSessionId, 'otpCode': otpCode},
      );

      final body = response.data;
      if (body == null) {
        return const Result.failure(
          UnknownFailure('Empty response from server during OTP verification.'),
        );
      }

      final session = _sessionFromJson(body);
      final accessToken = body['accessToken'] as String?;
      final refreshToken = body['refreshToken'] as String?;

      if (accessToken == null || refreshToken == null) {
        return const Result.failure(
          UnknownFailure('Server did not return valid session tokens.'),
        );
      }

      await _sessionStorage.saveSession(
        session: session,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      return Result.success(session);
    } on DioException catch (e) {
      return Result.failure(NetworkErrorMapper.map(e));
    } catch (e) {
      return Result.failure(UnknownFailure('Failed to verify OTP.', null, e));
    }
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final cached = await _sessionStorage.loadSession();
      if (cached == null) return const Result.success(null);

      // Cheap local restore first (fast app start); the auth interceptor
      // will still trigger a refresh on the first 401 if the token expired
      // while the app was closed.
      return Result.success(cached);
    } catch (e) {
      return Result.failure(
          StorageFailure('Failed to restore session.', 'STORAGE_ERROR', e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      // Best-effort server-side session invalidation; local clear happens
      // regardless of whether this call succeeds, so the user is never
      // stuck signed-in on-device due to a network error.
      await _apiClient.post<void>('/auth/logout');
    } on DioException {
      // Ignore — we still clear local session below.
    } finally {
      await _sessionStorage.clearSession();
    }
    return const Result.success(null);
  }

  @override
  Future<Result<AuthSession>> refreshSession() async {
    try {
      final refreshToken = await _sessionStorage.readRefreshToken();
      if (refreshToken == null) {
        return const Result.failure(
          UnauthorizedFailure(
              'No refresh token available. Please log in again.'),
        );
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final body = response.data;
      if (body == null) {
        return const Result.failure(
          UnauthorizedFailure('Session refresh failed. Please log in again.'),
        );
      }

      final session = _sessionFromJson(body);
      final newAccessToken = body['accessToken'] as String?;
      final newRefreshToken = body['refreshToken'] as String? ?? refreshToken;

      if (newAccessToken == null) {
        return const Result.failure(
          UnauthorizedFailure('Session refresh failed. Please log in again.'),
        );
      }

      await _sessionStorage.saveSession(
        session: session,
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return Result.success(session);
    } on DioException catch (e) {
      return Result.failure(NetworkErrorMapper.map(e));
    } catch (e) {
      return Result.failure(
          UnknownFailure('Failed to refresh session.', null, e));
    }
  }

  /// Maps the backend's session JSON payload to the domain [AuthSession].
  ///
  /// Expected shape (see docs/API_CONTRACTS.md — keep in sync with backend):
  /// ```json
  /// {
  ///   "userId": "...",
  ///   "phone": "+91 98765 XXXXX",
  ///   "role": "customer",
  ///   "displayName": "...",
  ///   "accountStatus": "active",
  ///   "issuedAt": "2026-09-17T10:00:00Z",
  ///   "accessToken": "...",
  ///   "refreshToken": "..."
  /// }
  /// ```
  AuthSession _sessionFromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role:
          UserRole.fromStorageKey(json['role'] as String?) ?? UserRole.customer,
      displayName: json['displayName'] as String?,
      accountStatus:
          AccountStatus.fromStorageKey(json['accountStatus'] as String?),
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
