import 'package:dio/dio.dart';
import '../../constants/app_constants.dart';

/// Interceptor that attaches correlation trace IDs and client headers to every outgoing request.
class CorrelationIdInterceptor extends Interceptor {
  final String appVersion;
  final String platform;
  final String deviceId;

  CorrelationIdInterceptor({
    this.appVersion = '1.0.0+1',
    this.platform = 'FLUTTER',
    this.deviceId = 'DEV_SIMULATOR',
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Generate simple time-based correlation ID if not set
    final correlationId = 'cid_${DateTime.now().microsecondsSinceEpoch}';
    options.headers.putIfAbsent(
      AppConstants.headerCorrelationId,
      () => correlationId,
    );
    options.headers.putIfAbsent(
      AppConstants.headerAppVersion,
      () => appVersion,
    );
    options.headers.putIfAbsent(AppConstants.headerPlatform, () => platform);
    options.headers.putIfAbsent(AppConstants.headerDeviceId, () => deviceId);

    handler.next(options);
  }
}
