import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';
import '../../security/secure_storage_service.dart';

/// Interceptor that attaches the Bearer JWT token to protected requests.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;

  /// Callback fired when a 401 survives a refresh attempt — the session is
  /// unrecoverable and the app must route to login. Injected by the provider
  /// layer to avoid a circular dependency on Riverpod from the core layer.
  final Future<void> Function()? onSessionExpired;

  AuthInterceptor(this._secureStorage, {this.onSessionExpired});

  /// Shared across the interceptor so concurrent 401s collapse into ONE
  /// refresh request (prevents refresh stampedes and token-reuse races).
  static Future<String?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if Authorization header is already manually supplied or endpoint is public
    if (!options.headers.containsKey(AppConstants.headerAuthorization)) {
      final token = await _secureStorage.read(AppConstants.keyAccessToken);
      if (token != null && token.isNotEmpty) {
        options.headers[AppConstants.headerAuthorization] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final isAuthRequest = err.requestOptions.path.contains('/auth/');

    // Only 401s on protected endpoints are refresh candidates.
    if (status != 401 || isAuthRequest) {
      handler.next(err);
      return;
    }

    // Idempotency-Key must not be reused for a retried mutating request
    // unless the server replays the same result — for booking submission it
    // SHOULD be reused (that is exactly the idempotency contract), so the
    // header is preserved as-is.

    final refreshToken = await _secureStorage.read(AppConstants.keyRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _notifyExpired();
      handler.next(err);
      return;
    }

    try {
      final newAccess = await _refreshSingleFlight(refreshToken, err.requestOptions);
      if (newAccess == null || newAccess.isEmpty) {
        await _notifyExpired();
        handler.next(err);
        return;
      }
      // Retry the original request ONCE with the fresh token.
      final opts = err.requestOptions;
      opts.headers[AppConstants.headerAuthorization] = 'Bearer $newAccess';
      final dio = Dio(BaseOptions(
        baseUrl: opts.baseUrl,
        connectTimeout: opts.connectTimeout,
        receiveTimeout: opts.receiveTimeout,
      ));
      final response = await dio.fetch<dynamic>(opts);
      handler.resolve(response);
      return;
    } catch (_) {
      await _notifyExpired();
      handler.next(err);
    }
  }

  /// Performs the refresh against the same base URL as the failed request.
  Future<String?> _refreshSingleFlight(
    String refreshToken,
    RequestOptions failedRequest,
  ) {
    // Collapse concurrent refresh attempts into one in-flight call.
    _refreshInFlight ??= _doRefresh(refreshToken, failedRequest);
    return _refreshInFlight!;
  }

  Future<String?> _doRefresh(
    String refreshToken,
    RequestOptions failedRequest,
  ) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: failedRequest.baseUrl));
      final response = await dio.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final body = response.data;
      final accessToken = body?['access_token'] as String?;
      final newRefresh = body?['refresh_token'] as String?;
      if (accessToken == null || accessToken.isEmpty) return null;
      await _secureStorage.write(AppConstants.keyAccessToken, accessToken);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _secureStorage.write(AppConstants.keyRefreshToken, newRefresh);
      }
      return accessToken;
    } finally {
      // Allow future refreshes once this one settles.
      Future.delayed(const Duration(milliseconds: 50), () {
        _refreshInFlight = null;
      });
    }
  }

  Future<void> _notifyExpired() async {
    try {
      await onSessionExpired?.call();
    } catch (_) {
      // Never let session-expiry handling break the error path.
    }
  }
}
