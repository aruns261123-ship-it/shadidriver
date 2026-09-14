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
import '../../features/services/domain/repositories/service_category_repository.dart';
import '../../features/services/domain/repositories/service_addon_repository.dart';
import '../../features/home/data/mock_repositories.dart';
import '../../features/vehicles/domain/entities/vehicle_summary.dart';
import '../../features/services/domain/entities/service_category.dart';
import '../../features/services/domain/entities/service_addon.dart';
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
  return MockDriverRepository();
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return MockVehicleRepository();
});

final serviceCategoryRepositoryProvider = Provider<ServiceCategoryRepository>((
  ref,
) {
  return MockServiceCategoryRepository();
});

final serviceAddonRepositoryProvider = Provider<ServiceAddonRepository>((ref) {
  return MockServiceAddonRepository();
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

// ---------------------------------------------------------------------------
// Home Feature State Providers
// ---------------------------------------------------------------------------

final featuredVehiclesProvider = FutureProvider<List<VehicleSummary>>((
  ref,
) async {
  final repo = ref.watch(vehicleRepositoryProvider);
  final result = await repo.getFeaturedVehicles();
  if (result.isSuccess) return result.dataOrNull!;
  throw result.failureOrNull!;
});

final serviceCategoriesProvider = FutureProvider<List<ServiceCategory>>((
  ref,
) async {
  final repo = ref.watch(serviceCategoryRepositoryProvider);
  final result = await repo.getCategories();
  if (result.isSuccess) return result.dataOrNull!;
  throw result.failureOrNull!;
});

final serviceAddonsProvider = FutureProvider<List<ServiceAddon>>((ref) async {
  final repo = ref.watch(serviceAddonRepositoryProvider);
  final result = await repo.getAddons();
  if (result.isSuccess) return result.dataOrNull!;
  throw result.failureOrNull!;
});
