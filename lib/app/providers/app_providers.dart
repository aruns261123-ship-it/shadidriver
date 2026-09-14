import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/env_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/logger_impl.dart';
import '../../core/network/api_client.dart';
import '../../core/security/flutter_secure_storage_impl.dart';
import '../../core/security/secure_storage_service.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/bookings/domain/repositories/booking_repository.dart';
import '../../features/drivers/domain/repositories/driver_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/payments/domain/repositories/payment_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../router/app_router.dart';

// ---------------------------------------------------------------------------
// Core Infrastructure Providers
// ---------------------------------------------------------------------------

/// Active environment configuration provider.
final environmentConfigProvider = Provider<EnvironmentConfig>((ref) {
  return EnvironmentConfig.development();
});

/// Centralized application logger provider.
final loggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(environmentConfigProvider);
  return AppLoggerImpl(enabled: config.enableNetworkLogging);
});

/// Hardware-backed secure storage provider.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return FlutterSecureStorageImpl();
});

/// Configured API client provider.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(environmentConfigProvider);
  final logger = ref.watch(loggerProvider);
  final storage = ref.watch(secureStorageProvider);

  return ApiClient(config: config, logger: logger, secureStorage: storage);
});

/// Centralized GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) {
  return createShadiRouter();
});

// ---------------------------------------------------------------------------
// Domain Repository Providers (Interfaces declared, implementations injected)
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'AuthRepository implementation will be provided in Phase 1',
  );
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  throw UnimplementedError(
    'BookingRepository implementation will be provided in Phase 4',
  );
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  throw UnimplementedError(
    'DriverRepository implementation will be provided in Phase 2',
  );
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  throw UnimplementedError(
    'VehicleRepository implementation will be provided in Phase 2',
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  throw UnimplementedError(
    'PaymentRepository implementation will be provided in Phase 5',
  );
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  throw UnimplementedError(
    'NotificationRepository implementation will be provided in Phase 6',
  );
});
