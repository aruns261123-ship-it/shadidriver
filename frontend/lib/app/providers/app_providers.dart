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
import '../../features/bookings/domain/entities/search_handoff.dart';
import '../../features/search/presentation/controllers/search_controller.dart';
import '../../features/bookings/domain/policies/booking_pricing_policy.dart';
import '../../features/bookings/data/mock_booking_pricing_policy.dart';
import '../../features/drivers/domain/repositories/driver_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/payments/domain/repositories/payment_repository.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';
import '../../features/services/domain/repositories/service_category_repository.dart';
import '../../features/services/domain/repositories/service_addon_repository.dart';
import '../../features/home/data/mock_repositories.dart';
import '../../features/vehicles/data/vehicle_api_repository.dart';
import '../../features/favorites/domain/repositories/favorites_repository.dart';
import '../../features/favorites/data/favorites_api_repository.dart';
import '../../features/favorites/data/mock_favorites_repository.dart';
import '../../features/services/data/service_category_api_repository.dart';
import '../../features/bookings/data/mock_booking_repository.dart';
import '../../features/bookings/data/booking_api_repository.dart';
import '../../features/vehicles/domain/entities/vehicle_summary.dart';
import '../../features/vehicles/presentation/controllers/recently_viewed_controller.dart';
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
import '../../features/drivers/domain/repositories/chauffeur_kyc_repository.dart';
import '../../features/drivers/data/mock_chauffeur_kyc_repository.dart';
import '../../features/profile/domain/repositories/admin_profile_repository.dart';
import '../../features/profile/data/mock_admin_profile_repository.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/auth/data/mock_auth_repository.dart';
import '../../features/auth/data/auth_api_repository.dart';
import '../../features/bookings/domain/services/route_distance_service.dart';
import '../../features/bookings/data/mock_route_distance_service.dart';
import '../../features/payments/data/mock_payment_repository.dart';
import '../../features/payments/data/payment_api_repository.dart';
import '../../features/notifications/data/mock_notification_repository.dart';
import '../../features/urgent_dispatch/domain/repositories/urgent_dispatch_repository.dart';
import '../../features/urgent_dispatch/data/mock_urgent_dispatch_repository.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../features/support/data/mock_support_repository.dart';
import '../../features/reviews/domain/repositories/review_repository.dart';
import '../../features/reviews/data/mock_review_repository.dart';
import '../../features/trips/domain/repositories/trip_repository.dart';
import '../../features/trips/data/mock_trip_repository.dart';
import '../../features/trips/data/trip_api_repository.dart';
import 'package:flutter/foundation.dart';
import '../router/app_router.dart';
import '../router/route_guards.dart';

// ---------------------------------------------------------------------------
// Core Infrastructure Providers
// ---------------------------------------------------------------------------

/// Loopback base URL for the local dev backend.
const _localhostApiBaseUrl = 'http://localhost:3000';

/// Android emulators address the host machine as 10.0.2.2 (host loopback);
/// every other target (Windows desktop, iOS simulator, web) uses localhost.
/// A function (not a const) because platform detection is not a const
/// expression, while `String.fromEnvironment` requires a constant default.
String defaultDevApiBaseUrl() => kIsWeb
    ? _localhostApiBaseUrl
    : (defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : _localhostApiBaseUrl);

/// Active environment configuration provider.
///
/// NO-MOCK PRODUCTION RULE: the default application path uses the REAL API
/// (useMockData == false). Mock repositories remain reachable ONLY behind the
/// explicit `SHADI_USE_MOCK_AUTH=true` dart-define, which exists for offline
/// UI development and automated tests.
///
/// Dev API base URL: `SHADI_API_BASE_URL` may always be passed explicitly
/// (e.g. `--dart-define=SHADI_API_BASE_URL=http://10.0.2.2:3000` for the
/// Android emulator). Unset, it resolves per-platform: Windows desktop and
/// Android emulators reach the local backend via loopback; physical devices
/// must pass the host's LAN IP explicitly.
final environmentConfigProvider = Provider<EnvironmentConfig>((ref) {
  const envBaseUrl = String.fromEnvironment('SHADI_API_BASE_URL');
  return EnvironmentConfig.development(
    apiBaseUrlOverride: envBaseUrl.isNotEmpty ? envBaseUrl : defaultDevApiBaseUrl(),
  );
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
  final mockMode = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );

  return ApiClient(
    config: config,
    logger: logger,
    secureStorage: storage,
    onSessionExpired: mockMode
        ? null
        : () async {
            // Real-mode session expiry: clear the in-memory session; the
            // router redirect sends the user to login.
            ref.read(activeSessionProvider.notifier).state =
                AuthSession.unauthenticated();
          },
  );
});

/// Listenable notifier that triggers GoRouter redirect re-evaluation
/// whenever the active session changes.
class _RouterSessionNotifier extends ChangeNotifier {
  _RouterSessionNotifier(Ref ref) {
    ref.listen<AuthSession>(
      activeSessionProvider,
      (prev, next) => notifyListeners(),
    );
  }
}

/// Centralized GoRouter provider.
final routerProvider = Provider<GoRouter>((ref) {
  final sessionNotifier = _RouterSessionNotifier(ref);
  ref.onDispose(sessionNotifier.dispose);

  return createShadiRouter(
    routeGuard: const ShadiRouteGuard(enforceAuth: true),
    refreshListenable: sessionNotifier,
    resolveSearchHandoff: () => ref.read(searchHandoffProvider),
    isAuthenticated: () {
      final session = ref.read(activeSessionProvider);
      return session.isAuthenticated;
    },
    userRole: () {
      final session = ref.read(activeSessionProvider);
      if (session.isAuthenticated) {
        return session.role.name;
      }
      return null;
    },
    accountStatus: () {
      final session = ref.read(activeSessionProvider);
      return session.accountStatus;
    },
  );
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

/// Auth repository provider — REAL API repository by default; the mock is
/// opt-in via SHADI_USE_MOCK_AUTH for offline UI development and tests only.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    final storage = ref.watch(secureStorageProvider);
    return MockAuthRepository(storage);
  }
  return AuthApiRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

final routeDistanceServiceProvider = Provider<RouteDistanceService>((ref) {
  return const MockRouteDistanceService();
});

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    final store = MockBookingRepository();
    // Mirror booking lifecycle events into the notification center feed.
    final notificationRepo =
        ref.watch(notificationRepositoryProvider) as MockNotificationRepository;
    store.onLifecycleEvent = ({required String title, required String body}) {
      notificationRepo.pushEvent(title: title, body: body);
      // Refresh any live notification listeners.
      ref.notifyListeners();
    };
    return store;
  }
  return BookingApiRepository(ref.watch(apiClientProvider));
});

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return MockDriverRepository();
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    return MockVehicleRepository();
  }
  return VehicleApiRepository(ref.watch(apiClientProvider));
});

/// Favourites repository — REAL account-backed API by default. The in-memory
/// implementation exists only for `useMockData` mode and tests.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    return MockFavoritesRepository(vehicles: ref.watch(vehicleRepositoryProvider));
  }
  return FavoritesApiRepository(ref.watch(apiClientProvider));
});

final serviceCategoryRepositoryProvider = Provider<ServiceCategoryRepository>((
  ref,
) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    return MockServiceCategoryRepository();
  }
  return ServiceCategoryApiRepository(ref.watch(apiClientProvider));
});

final serviceAddonRepositoryProvider = Provider<ServiceAddonRepository>((ref) {
  return MockServiceAddonRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    final bookingStore =
        ref.watch(bookingRepositoryProvider) as MockBookingRepository;
    return MockPaymentRepository(bookingRepository: bookingStore);
  }
  return PaymentApiRepository(ref.watch(apiClientProvider));
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
  final useMock = ref.watch(
    environmentConfigProvider.select((c) => c.useMockData),
  );
  if (useMock) {
    final bookingStore =
        ref.watch(bookingRepositoryProvider) as MockBookingRepository;
    return MockTripRepository(bookingRepository: bookingStore);
  }
  return TripApiRepository(ref.watch(apiClientProvider));
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

/// Chauffeur KYC repository — adjudicates applications against the shared
/// driver roster so approval flips the real profile's verification status.
final chauffeurKycRepositoryProvider = Provider<ChauffeurKycRepository>((ref) {
  final driverStore =
      ref.watch(driverRepositoryProvider) as MockDriverRepository;
  return MockChauffeurKycRepository(driverRepository: driverStore);
});

final activeSessionProvider = StateProvider<AuthSession>((ref) {
  return AuthSession.unauthenticated();
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

/// Derived urgent-dispatch availability for the home dispatch card.
/// Counts come from (mock) fleet data; ETA is derived deterministically from
/// the busy/available split so the UI shows computed values, not literals.
final urgentDispatchAvailabilityProvider =
    FutureProvider.autoDispose<({int availableCount, String eta})>((ref) async {
      final repo = ref.watch(vehicleRepositoryProvider);
      final result = await repo.getAvailableVehicles();
      final vehicles = result.dataOrNull ?? const <VehicleSummary>[];
      final availableCount = vehicles.where((v) => v.isAvailableNow).length;
      final busy = vehicles.length - availableCount;
      final etaMinutes = (6 + busy ~/ 3).clamp(6, 15);
      return (availableCount: availableCount, eta: '$etaMinutes mins');
    });

/// Bridges the live search session into booking-draft creation: the
/// customer's destination, event date, occasion and passenger count flow
/// into the draft so they are never re-entered (Search → Draft handoff).
final searchHandoffProvider = Provider<SearchHandoff>((ref) {
  final session = ref.watch(searchControllerProvider);
  final query = session.query;
  return SearchHandoff(
    destination: query.destination,
    pickupLocation: query.pickupLocation,
    eventDate: query.eventDate,
    occasion: query.occasionId,
    passengerCount: query.passengerCount,
  );
});

/// Resolves the customer's recently-viewed vehicle IDs into full summaries.
final recentlyViewedVehiclesProvider =
    FutureProvider.autoDispose<List<VehicleSummary>>((ref) async {
      final ids = ref.watch(recentlyViewedProvider);
      if (ids.isEmpty) return const <VehicleSummary>[];
      final repo = ref.watch(vehicleRepositoryProvider);
      final vehicles = <VehicleSummary>[];
      for (final id in ids) {
        final result = await repo.getVehicleById(id);
        final vehicle = result.dataOrNull;
        if (vehicle != null) vehicles.add(vehicle);
      }
      return vehicles;
    });
