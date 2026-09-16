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
import '../../features/bookings/domain/policies/booking_pricing_policy.dart';
import '../../features/bookings/data/mock_booking_pricing_policy.dart';
import '../../features/drivers/domain/repositories/driver_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/payments/domain/repositories/payment_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../features/services/domain/repositories/service_category_repository.dart';
import '../../features/services/domain/repositories/service_addon_repository.dart';
import '../../features/home/data/mock_repositories.dart';
import '../../features/bookings/data/mock_booking_repository.dart';
import '../../features/vehicles/domain/entities/vehicle_summary.dart';
import '../../features/services/domain/entities/service_category.dart';
import '../../features/services/domain/entities/service_addon.dart';
import '../../features/profile/domain/services/profile_photo_service.dart';
import '../../features/profile/data/mock_profile_photo_service.dart';
import '../../features/profile/domain/repositories/saved_addresses_repository.dart';
import '../../features/profile/data/mock_saved_addresses_repository.dart';
import '../../features/profile/domain/repositories/customer_profile_repository.dart';
import '../../features/profile/data/mock_customer_profile_repository.dart';
import '../../features/drivers/domain/repositories/driver_profile_repository.dart';
import '../../features/drivers/data/mock_driver_profile_repository.dart';
import '../../features/profile/domain/repositories/admin_profile_repository.dart';
import '../../features/profile/data/mock_admin_profile_repository.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/domain/entities/account_status.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../../features/bookings/domain/services/route_distance_service.dart';
import '../../features/bookings/data/mock_route_distance_service.dart';
import '../../features/payments/data/mock_payment_repository.dart';
import '../../features/notifications/data/mock_notification_repository.dart';
import '../../features/urgent_dispatch/domain/repositories/urgent_dispatch_repository.dart';
import '../../features/urgent_dispatch/data/mock_urgent_dispatch_repository.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../features/support/data/mock_support_repository.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/reviews/data/mock_review_repository.dart';
import '../../features/trips/domain/repositories/trip_repository.dart';
import '../../features/trips/data/mock_trip_repository.dart';
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
// Pricing & Policy Providers (Provisional development policies)
// ---------------------------------------------------------------------------

/// Provisional development advance payment policy provider.
final advancePaymentPolicyProvider = Provider<AdvancePaymentPolicy>((ref) {
  return const DevelopmentAdvancePaymentPolicy();
});

/// Provisional development booking pricing policy provider.
final bookingPricingPolicyProvider = Provider<BookingPricingPolicy>((ref) {
  final advancePolicy = ref.watch(advancePaymentPolicyProvider);
  return DevelopmentBookingPricingPolicy(advancePaymentPolicy: advancePolicy);
});

// ---------------------------------------------------------------------------
// Domain Repository Providers (Interfaces declared, implementations injected)
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

final routeDistanceServiceProvider = Provider<RouteDistanceService>((ref) {
  return const MockRouteDistanceService();
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return MockBookingRepository();
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
  return MockPaymentRepository();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return MockNotificationRepository();
});

final urgentDispatchRepositoryProvider = Provider<UrgentDispatchRepository>((
  ref,
) {
  return MockUrgentDispatchRepository();
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return MockSupportRepository();
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return MockReviewRepository();
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return MockTripRepository();
});

final profilePhotoServiceProvider = Provider<ProfilePhotoService>((ref) {
  return MockProfilePhotoService();
});

final savedAddressesRepositoryProvider = Provider<SavedAddressesRepository>((
  ref,
) {
  return MockSavedAddressesRepository();
});

final customerProfileRepositoryProvider = Provider<CustomerProfileRepository>((
  ref,
) {
  return MockCustomerProfileRepository();
});

final driverProfileRepositoryProvider = Provider<DriverProfileRepository>((
  ref,
) {
  return MockDriverProfileRepository();
});

final adminProfileRepositoryProvider = Provider<AdminProfileRepository>((ref) {
  return MockAdminProfileRepository();
});

final activeSessionProvider = StateProvider<AuthSession>((ref) {
  return AuthSession(
    userId: 'cust_101',
    phone: '+91 98765 43210',
    role: UserRole.customer,
    displayName: 'Aditya Singhal',
    accountStatus: AccountStatus.active,
    issuedAt: DateTime.now(),
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
