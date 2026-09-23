import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/user_role.dart';
import '../domain/repositories/auth_repository.dart';

/// Real backend auth repository — hits /auth/otp/request, /auth/signup,
/// /auth/otp/verify, /auth/refresh, /auth/logout, /auth/me.
///
/// Tokens persist to secure storage BEFORE resolving so a crash after login
/// still restores the session. Role and account status are taken ONLY from
/// the server identity — never client-supplied.
class AuthApiRepository implements AuthRepository {
  final ApiClient _client;
  final SecureStorageService _storage;

  AuthApiRepository(this._client, this._storage);

  static const _basePath = '${AppConstants.apiV1Prefix}/auth';

  Future<String?> _accessToken() => _storage.read(AppConstants.keyAccessToken);

  /// Builds an [AuthSession] from the wire `user` object and persists tokens.
  Future<AuthSession> _persistAndBuildSession(Map<String, dynamic> body) async {
    final user = (body['user'] as Map<String, dynamic>?) ?? const {};
    final accessToken = body['access_token'] as String?;
    final refreshToken = body['refresh_token'] as String?;

    if (accessToken != null && accessToken.isNotEmpty) {
      await _storage.write(AppConstants.keyAccessToken, accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(AppConstants.keyRefreshToken, refreshToken);
    }

    final userId = (user['id'] as String?) ?? '';
    final roleWire = user['role'] as String?;
    final issuedAt = userId.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.now().toUtc();

    // Persist identity snapshot for the router and profile screens.
    await _storage.write(AppConstants.keyUserId, userId);
    if (roleWire != null) {
      await _storage.write(AppConstants.keyUserRole, roleWire);
    }
    final statusWire = user['account_status'] as String?;
    if (statusWire != null) {
      await _storage.write(AppConstants.keyAccountStatus, statusWire);
    }
    final fullName = user['full_name'] as String?;
    if (fullName != null) {
      await _storage.write(AppConstants.keyDisplayName, fullName);
    }
    final phone = user['phone_number'] as String?;
    if (phone != null) {
      await _storage.write(AppConstants.keyPhone, phone);
    }

    return AuthSession(
      userId: userId,
      phone: phone != null && phone.length >= 4
          ? '+91 ••••• ${phone.substring(phone.length - 4)}'
          : (phone ?? ''),
      role: parseUserRole(roleWire),
      displayName: fullName,
      accountStatus: parseAccountStatus(statusWire),
      issuedAt: issuedAt,
    );
  }

  @override
  Future<Result<String>> requestOtp({
    required String phoneNumber,
    UserRole? role,
  }) async {
    try {
      // role is advisory in dev only; server decides everything authoritative.
      final response = await _client.post<Map<String, dynamic>>(
        '$_basePath/otp/request',
        data: {'phone_number': phoneNumber, 'purpose': 'LOGIN'},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final sessionId = data['session_id'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        return Result.failure(const UnknownFailure(
          'OTP request was not accepted by the server.',
          'OTP_SESSION_NOT_FOUND',
        ));
      }
      return Result.success(sessionId);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<String>> signUp({
    required String phoneNumber,
    required String displayName,
    UserRole role = UserRole.customer,
  }) async {
    try {
      // Public signup is limited to customer/driver server-side; admins are
      // provisioned internally. We still send only these two roles.
      final wireRole = role == UserRole.driver ? 'driver' : 'customer';
      final response = await _client.post<Map<String, dynamic>>(
        '$_basePath/signup',
        data: {
          'phone_number': phoneNumber,
          'display_name': displayName,
          'role': wireRole,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final sessionId = data['session_id'] as String?;
      if (sessionId == null || sessionId.isEmpty) {
        return Result.failure(const UnknownFailure(
          'Registration was not accepted by the server.',
          'UNKNOWN_ERROR',
        ));
      }
      return Result.success(sessionId);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String otpSessionId,
    required String otpCode,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '$_basePath/otp/verify',
        data: {
          'session_id': otpSessionId,
          'otp_code': otpCode,
          'device_id': await _deviceId(),
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final session = await _persistAndBuildSession(data);
      if (session.userId.isEmpty) {
        return Result.failure(const UnknownFailure(
          'Verification succeeded but no identity was returned.',
          'UNKNOWN_ERROR',
        ));
      }
      return Result.success(session);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    try {
      final refreshToken = await _storage.read(AppConstants.keyRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        return const Result.success(null);
      }
      // Exchange the stored refresh token for a fresh pair; the backend
      // rotates it (reuse detection revokes stolen chains).
      final response = await _client.post<Map<String, dynamic>>(
        '$_basePath/refresh',
        data: {'refresh_token': refreshToken, 'device_id': await _deviceId()},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final session = await _persistAndBuildSession(data);
      if (session.userId.isEmpty) {
        return const Result.success(null);
      }
      return Result.success(session);
    } catch (e) {
      // Corrupt/expired refresh chain → force a clean login.
      await _clearTokens();
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      final refreshToken = await _storage.read(AppConstants.keyRefreshToken);
      final access = await _accessToken();
      // Best-effort server revocation (works with or without access token).
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _client.post<void>(
          '$_basePath/logout',
          data: {'refresh_token': refreshToken},
          options: access != null
              ? Options(headers: {
                  AppConstants.headerAuthorization: 'Bearer $access',
                })
              : null,
        );
      }
      return const Result.success(null);
    } catch (_) {
      // Local sign-out always succeeds even if the server call fails.
      return const Result.success(null);
    } finally {
      await _clearTokens();
    }
  }

  @override
  Future<Result<AuthSession>> refreshSession() async {
    try {
      final refreshToken = await _storage.read(AppConstants.keyRefreshToken);
      if (refreshToken == null || refreshToken.isEmpty) {
        return const Result.failure(UnauthorizedFailure(
          'No session to refresh.',
          'UNAUTHORIZED',
        ));
      }
      final response = await _client.post<Map<String, dynamic>>(
        '$_basePath/refresh',
        data: {'refresh_token': refreshToken, 'device_id': await _deviceId()},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final session = await _persistAndBuildSession(data);
      if (session.userId.isEmpty) {
        return Result.failure(const UnauthorizedFailure(
          'Refresh returned no identity.',
          'UNAUTHORIZED',
        ));
      }
      return Result.success(session);
    } catch (e) {
      await _clearTokens();
      return Result.failure(mapDioError(e));
    }
  }

  Future<void> _clearTokens() async {
    await _storage.delete(AppConstants.keyAccessToken);
    await _storage.delete(AppConstants.keyRefreshToken);
  }

  Future<String> _deviceId() async {
    final existing = await _storage.read(AppConstants.keyDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated =
        'dev-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    await _storage.write(AppConstants.keyDeviceId, generated);
    return generated;
  }
}
