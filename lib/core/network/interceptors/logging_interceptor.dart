import 'package:dio/dio.dart';
import '../../logging/app_logger.dart';

/// Network logging interceptor that ensures strict redaction of sensitive credentials.
class NetworkLoggingInterceptor extends Interceptor {
  final AppLogger _logger;
  final bool enabled;

  NetworkLoggingInterceptor(this._logger, {this.enabled = true});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      final sanitizedUri = AppLogger.redact(options.uri.toString());
      final sanitizedHeaders = AppLogger.redact(options.headers.toString());
      final sanitizedData = options.data != null
          ? AppLogger.redact(options.data.toString())
          : 'null';

      _logger.debug(
        '--> HTTP ${options.method} $sanitizedUri\n'
        'Headers: $sanitizedHeaders\n'
        'Body: $sanitizedData',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      final sanitizedData = response.data != null
          ? AppLogger.redact(response.data.toString())
          : 'null';

      _logger.debug(
        '<-- HTTP ${response.statusCode} ${response.requestOptions.uri}\n'
        'Response: $sanitizedData',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _logger.error(
        '<-- HTTP ERROR ${err.response?.statusCode} ${err.requestOptions.uri}\n'
        'Message: ${err.message}',
        err,
      );
    }
    handler.next(err);
  }
}
