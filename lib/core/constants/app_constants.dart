/// Global application-wide constants.
abstract final class AppConstants {
  static const String appName = 'ShadiDriver';
  static const String appTagline = 'Luxury Wedding & Event Chauffeurs';

  // Secure Storage Keys
  static const String keyAccessToken = 'shadi_access_token';
  static const String keyRefreshToken = 'shadi_refresh_token';
  static const String keyUserRole = 'shadi_user_role';
  static const String keyUserId = 'shadi_user_id';
  static const String keyDeviceId = 'shadi_device_id';

  // Header Keys
  static const String headerAuthorization = 'Authorization';
  static const String headerIdempotencyKey = 'Idempotency-Key';
  static const String headerCorrelationId = 'X-Correlation-ID';
  static const String headerAppVersion = 'X-App-Version';
  static const String headerPlatform = 'X-Platform';
  static const String headerDeviceId = 'X-Device-ID';

  // Pagination & Timings
  static const int defaultPageSize = 20;
  static const Duration otpCooldownDuration = Duration(seconds: 30);
  static const Duration bookingAcceptanceTimeout = Duration(minutes: 15);
  static const Duration telemetryInterval = Duration(seconds: 3);
}
