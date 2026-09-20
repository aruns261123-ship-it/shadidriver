import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';
import '../../security/secure_storage_service.dart';

/// Interceptor that attaches the Bearer JWT token to protected requests.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage;

  AuthInterceptor(this._secureStorage);

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
}
