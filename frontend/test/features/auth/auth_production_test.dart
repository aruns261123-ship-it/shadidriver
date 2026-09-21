import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_guards.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/security/secure_storage_service.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/account_status.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_state.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shadidriver/features/auth/presentation/dev_auth_harness.dart';
import 'package:shadidriver/features/auth/presentation/login_screen.dart';
import 'package:shadidriver/features/home/presentation/splash_screen.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}

void main() {
  group('Section M: 18 ShadiDriver Production Authentication Tests', () {
    late InMemorySecureStorage secureStorage;
    late MockAuthRepository authRepo;

    setUp(() {
      secureStorage = InMemorySecureStorage();
      authRepo = MockAuthRepository(secureStorage, false);
    });

    // -------------------------------------------------------------------------
    // TEST 1: Fresh app with no session → Splash → Login
    // -------------------------------------------------------------------------
    testWidgets('1. Fresh app with no session routes from Splash to Login', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          secureStorageProvider.overrideWithValue(secureStorage),
        ],
      );
      addTearDown(container.dispose);

      final router = createShadiRouter(
        initialLocation: RoutePaths.splash,
        routeGuard: const ShadiRouteGuard(enforceAuth: true),
        isAuthenticated: () =>
            container.read(activeSessionProvider).isAuthenticated,
        userRole: () => container.read(activeSessionProvider).role.name,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        router.routeInformationProvider.value.uri.path,
        equals(RoutePaths.auth),
      );
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Existing Customer session → Splash → Customer Home
    // -------------------------------------------------------------------------
    testWidgets(
      '2. Existing Customer session routes from Splash to Customer Home',
      (tester) async {
        await authRepo.devSignInAsRole(UserRole.customer);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final router = createShadiRouter(
          initialLocation: RoutePaths.splash,
          routeGuard: const ShadiRouteGuard(enforceAuth: true),
          isAuthenticated: () =>
              container.read(activeSessionProvider).isAuthenticated,
          userRole: () => container.read(activeSessionProvider).role.name,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          equals(RoutePaths.customerHome),
        );
      },
    );

    // -------------------------------------------------------------------------
    // TEST 3: Existing Driver session → Splash → Chauffeur Dashboard
    // -------------------------------------------------------------------------
    testWidgets(
      '3. Existing Driver session routes from Splash to Driver Dashboard',
      (tester) async {
        await authRepo.devSignInAsRole(UserRole.driver);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final router = createShadiRouter(
          initialLocation: RoutePaths.splash,
          routeGuard: const ShadiRouteGuard(enforceAuth: true),
          isAuthenticated: () =>
              container.read(activeSessionProvider).isAuthenticated,
          userRole: () => container.read(activeSessionProvider).role.name,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          equals(RoutePaths.driver),
        );
      },
    );

    // -------------------------------------------------------------------------
    // TEST 4: Existing Admin session → Splash → Admin Command Hub
    // -------------------------------------------------------------------------
    testWidgets(
      '4. Existing Admin session routes from Splash to Admin Command Hub',
      (tester) async {
        await authRepo.devSignInAsRole(UserRole.operationsAdmin);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final router = createShadiRouter(
          initialLocation: RoutePaths.splash,
          routeGuard: const ShadiRouteGuard(enforceAuth: true),
          isAuthenticated: () =>
              container.read(activeSessionProvider).isAuthenticated,
          userRole: () => container.read(activeSessionProvider).role.name,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.path,
          equals(RoutePaths.admin),
        );
      },
    );

    // -------------------------------------------------------------------------
    // TEST 5: Invalid/expired session → Login
    // -------------------------------------------------------------------------
    test(
      '5. Invalid/expired session fails restoration and transitions to Unauthenticated',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.restoreSession();

        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(container.read(activeSessionProvider).isAuthenticated, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 6: Customer with incomplete profile → Customer Profile Creation
    // -------------------------------------------------------------------------
    test(
      '6. Route guard routes customer with incomplete profile to customer profile edit',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.customerHome,
          isAuthenticated: true,
          userRole: 'customer',
          accountStatus: AccountStatus.profileIncomplete,
        );

        expect(redirect, equals(RoutePaths.customerProfileEdit));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 7: Driver with incomplete profile → Chauffeur Profile Creation / Verification
    // -------------------------------------------------------------------------
    test(
      '7. Route guard routes driver with incomplete profile to driver profile edit',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.driver,
          isAuthenticated: true,
          userRole: 'driver',
          accountStatus: AccountStatus.profileIncomplete,
        );

        expect(redirect, equals(RoutePaths.driverProfileEdit));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 8: Admin cannot be created through public registration
    // -------------------------------------------------------------------------
    test('8. Admin cannot be created through public registration', () async {
      final result = await authRepo.requestOtp(
        phoneNumber: '9988776655', // Unregistered arbitrary public number
        role: UserRole.operationsAdmin,
      );

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.code,
        equals('ADMIN_REGISTRATION_PROHIBITED'),
      );
    });

    // -------------------------------------------------------------------------
    // TEST 9: Customer cannot navigate to driver routes
    // -------------------------------------------------------------------------
    test(
      '9. Customer cannot navigate to driver routes (redirects to /customer)',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.driver,
          isAuthenticated: true,
          userRole: 'customer',
          accountStatus: AccountStatus.active,
        );

        expect(redirect, equals(RoutePaths.customer));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 10: Customer cannot navigate to admin routes
    // -------------------------------------------------------------------------
    test(
      '10. Customer cannot navigate to admin routes (redirects to /customer)',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.admin,
          isAuthenticated: true,
          userRole: 'customer',
          accountStatus: AccountStatus.active,
        );

        expect(redirect, equals(RoutePaths.customer));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 11: Driver cannot navigate to customer routes
    // -------------------------------------------------------------------------
    test(
      '11. Driver cannot navigate to customer routes (redirects to /driver)',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.customerHome,
          isAuthenticated: true,
          userRole: 'driver',
          accountStatus: AccountStatus.active,
        );

        expect(redirect, equals(RoutePaths.driver));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 12: Driver cannot navigate to admin routes
    // -------------------------------------------------------------------------
    test(
      '12. Driver cannot navigate to admin routes (redirects to /driver)',
      () async {
        const guard = ShadiRouteGuard(enforceAuth: true);
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.admin,
          isAuthenticated: true,
          userRole: 'driver',
          accountStatus: AccountStatus.active,
        );

        expect(redirect, equals(RoutePaths.driver));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 13: Developer bypass is not rendered in production authentication UI
    // -------------------------------------------------------------------------
    testWidgets(
      '13. Developer bypass is not rendered in production authentication UI',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: LoginScreen())),
        );
        await tester.pump();

        expect(find.text('Developer Quick Bypass (1-Tap)'), findsNothing);
        expect(find.text('Developer Quick Bypass'), findsNothing);
        expect(find.text('🚗 Host (Customer)'), findsNothing);
        expect(find.text('🎩 Chauffeur (Driver)'), findsNothing);
        expect(find.text('🏢 Operations Admin'), findsNothing);
        expect(find.text('Select Portal Role'), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 14: Invalid OTP remains unauthenticated
    // -------------------------------------------------------------------------
    test(
      '14. Invalid OTP fails verification and state remains unauthenticated',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        final req = await controller.requestOtp(
          phoneNumber: DevAuthHarness.customerPhone,
        );
        expect(req.isSuccess, isTrue);

        final verify = await controller.verifyOtp(
          otpSessionId: req.dataOrNull!,
          otpCode: '888888', // Invalid OTP
        );

        expect(verify.isFailure, isTrue);
        expect(container.read(authControllerProvider), isA<AuthError>());
        expect(container.read(activeSessionProvider).isAuthenticated, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 15: Successful OTP verification produces authenticated session
    // -------------------------------------------------------------------------
    test(
      '15. Successful OTP verification produces valid authenticated session',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        final req = await controller.requestOtp(
          phoneNumber: DevAuthHarness.customerPhone,
        );
        expect(req.isSuccess, isTrue);

        final verify = await controller.verifyOtp(
          otpSessionId: req.dataOrNull!,
          otpCode: DevAuthHarness.universalOtp,
        );

        expect(verify.isSuccess, isTrue);
        expect(container.read(authControllerProvider), isA<Authenticated>());
        final session = container.read(activeSessionProvider);
        expect(session.isAuthenticated, isTrue);
        expect(session.role, equals(UserRole.customer));
        expect(session.accountStatus, equals(AccountStatus.active));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 16: Sign out → Login
    // -------------------------------------------------------------------------
    test(
      '16. Sign out clears session and returns to Unauthenticated state',
      () async {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(authControllerProvider.notifier);
        await controller.devLoginAsRole(UserRole.customer);
        expect(container.read(activeSessionProvider).isAuthenticated, isTrue);

        await controller.signOut();
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(container.read(activeSessionProvider).isAuthenticated, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 17: App restart after sign out → Login
    // -------------------------------------------------------------------------
    test(
      '17. App restart after sign out restores empty session and stays unauthenticated',
      () async {
        // Step A: Login then sign out
        final container1 = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        await container1
            .read(authControllerProvider.notifier)
            .devLoginAsRole(UserRole.customer);
        await container1.read(authControllerProvider.notifier).signOut();
        container1.dispose();

        // Step B: Simulate app restart with a new repository/container reading the same storage
        final restartRepo = MockAuthRepository(secureStorage, false);
        final container2 = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(restartRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container2.dispose);

        await container2.read(authControllerProvider.notifier).restoreSession();

        expect(container2.read(authControllerProvider), isA<Unauthenticated>());
        expect(container2.read(activeSessionProvider).isAuthenticated, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 18: App restart with valid session → correct role destination
    // -------------------------------------------------------------------------
    test(
      '18. App restart with valid session restores authenticated driver role',
      () async {
        // Step A: Login as Driver
        final container1 = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        await container1
            .read(authControllerProvider.notifier)
            .devLoginAsRole(UserRole.driver);
        container1.dispose();

        // Step B: Simulate app restart
        final restartRepo = MockAuthRepository(secureStorage, false);
        final container2 = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(restartRepo),
            secureStorageProvider.overrideWithValue(secureStorage),
          ],
        );
        addTearDown(container2.dispose);

        await container2.read(authControllerProvider.notifier).restoreSession();

        expect(container2.read(authControllerProvider), isA<Authenticated>());
        final restoredSession = container2.read(activeSessionProvider);
        expect(restoredSession.isAuthenticated, isTrue);
        expect(restoredSession.role, equals(UserRole.driver));
      },
    );
  });
}
