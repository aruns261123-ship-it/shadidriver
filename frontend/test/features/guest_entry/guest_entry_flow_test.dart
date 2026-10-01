import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_guards.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/config/env_config.dart';
import 'package:shadidriver/core/logging/app_logger.dart';
import 'package:shadidriver/core/network/api_client.dart';
import 'package:shadidriver/core/network/api_response.dart';
import 'package:shadidriver/core/security/in_memory_secure_storage.dart';
import 'package:shadidriver/features/auth/data/mock_auth_repository.dart';
import 'package:shadidriver/features/auth/domain/entities/auth_state.dart';
import 'package:shadidriver/features/auth/domain/entities/user_role.dart';
import 'package:shadidriver/features/auth/presentation/controllers/auth_controller.dart';
import 'package:shadidriver/features/auth/presentation/login_screen.dart';
import 'package:shadidriver/features/bookings/domain/entities/guest_fleet_selection.dart';
import 'package:shadidriver/features/bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import 'package:shadidriver/features/home/presentation/customer_home_screen.dart';
import 'package:shadidriver/features/home/presentation/splash_screen.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/presentation/controllers/search_controller.dart';
import 'package:shadidriver/features/search/presentation/search_results_screen.dart';
import 'package:shadidriver/features/vehicles/data/dto/public_vehicle_dto.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';

import '../../helpers/mock_env.dart';

void main() {
  group('GUEST-FIRST ENTRY — routing & guard contracts', () {
    final strict = const ShadiRouteGuard(enforceAuth: true);

    Future<String?> decide(String location) => strict.evaluateRedirect(
          targetLocation: location,
          isAuthenticated: false,
          userRole: null,
        );

    test('1. fresh app with no session opens Customer Home (no login wall)',
        () async {
      expect(await decide(RoutePaths.customerHome), isNull);
      expect(await decide(RoutePaths.customer), isNull);
    });

    test('2. signed-out user can open vehicle list & search', () async {
      expect(await decide(RoutePaths.customerSearch), isNull);
      expect(await decide(RoutePaths.customerSearchResults), isNull);
    });

    test('3. signed-out user can open vehicle details', () async {
      expect(
        await decide(RoutePaths.customerVehicleDetailsPath('v1')),
        isNull,
      );
    });

    test('4. selection review (fleet builder) is a guest surface', () async {
      expect(await decide(RoutePaths.customerGroupBooking), isNull);
    });

    test('5. favorites shortlist view is a guest surface', () async {
      expect(await decide(RoutePaths.customerFavorites), isNull);
    });

    test('6. protected actions still require authentication', () async {
      for (final location in <String>[
        '/customer/bookings',
        '/customer/bookings/create/v1',
        '/customer/profile',
        '/customer/profile/edit',
        '/customer/addresses',
      ]) {
        final redirect = await decide(location);
        expect(redirect, isNotNull, reason: '$location must require auth');
        expect(redirect, startsWith('/auth'));
        // The redirect preserves the destination for post-login return.
        expect(redirect, contains('redirect='));
      }
    });

    test('7. a signed-out visitor defaults to the customer home', () {
      expect(ShadiRouteGuard.getRoleHome(null), RoutePaths.customer);
    });

    test('8. role homes are unchanged for authenticated users', () {
      expect(ShadiRouteGuard.getRoleHome('customer'), RoutePaths.customer);
      expect(ShadiRouteGuard.getRoleHome('driver'), RoutePaths.driver);
      expect(ShadiRouteGuard.getRoleHome('fleetOwner'), RoutePaths.driver);
      expect(ShadiRouteGuard.getRoleHome('operationsAdmin'), RoutePaths.admin);
      expect(ShadiRouteGuard.getRoleHome('superAdmin'), RoutePaths.admin);
    });
  });

  group('GUEST-FIRST ENTRY — widget flows', () {
    late InMemorySecureStorage secureStorage;
    late MockAuthRepository authRepo;

    setUp(() {
      secureStorage = InMemorySecureStorage();
      authRepo = MockAuthRepository(secureStorage, false);
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(overrides: [
        ...mockModeOverrides(),
        authRepositoryProvider.overrideWithValue(authRepo),
        secureStorageProvider.overrideWithValue(secureStorage),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    GoRouter makeRouter(ProviderContainer container) => createShadiRouter(
          initialLocation: RoutePaths.splash,
          routeGuard: const ShadiRouteGuard(enforceAuth: true),
          isAuthenticated: () =>
              container.read(activeSessionProvider).isAuthenticated,
          userRole: () => container.read(activeSessionProvider).role.name,
        );

    /// TEST A: Splash → Customer Home for a signed-out visitor.
    testWidgets(
      'TEST A: fresh app lands on Customer Home, never on the login wall',
      (tester) async {
        final container = makeContainer();
        final router = makeRouter(container);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        expect(find.byType(SplashScreen), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          router.routeInformationProvider.value.uri.path,
          RoutePaths.customerHome,
        );
        expect(find.byType(CustomerHomeScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        // The guest selection model is registered and empty at start.
        expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      },
    );

    /// TEST B: guest selection state machine — multi-vehicle, quantities.
    test(
      'TEST B: guest can add multiple vehicles and change quantities',
      () {
        final container = makeContainer();
        final sel = container.read(guestFleetSelectionProvider.notifier);

        // "Browse Thar → Add Thar → Browse Scorpio → Add Scorpio"
        sel.addType(
          vehicleTypeId: 'VT_THAR',
          displayName: 'Mahindra Thar',
          vehicleClass: 'Premium SUV',
          seatingCapacity: 5,
        );
        sel.addType(
          vehicleTypeId: 'VT_SCORPIO',
          displayName: 'Mahindra Scorpio',
          vehicleClass: 'Premium SUV',
          seatingCapacity: 7,
        );
        expect(container.read(guestFleetSelectionProvider).totalVehicles, 2);

        // Quantity change: 2 Thars.
        sel.setQuantity('VT_THAR', 2);
        expect(container.read(guestFleetSelectionProvider).totalVehicles, 3);

        // Removing one type entirely.
        sel.removeType('VT_SCORPIO');
        final after = container.read(guestFleetSelectionProvider);
        expect(after.totalVehicles, 2);
        expect(after.containsType('VT_SCORPIO'), isFalse);

        // The controller must be keepAlive (not autoDispose): the selection
        // outlives screens — that is the whole point.
        expect(container.read(guestFleetSelectionProvider.notifier), same(sel));
      },
    );

    /// TEST C: the search results list carries the guest add affordance and
    /// never redirects to login while browsing.
    testWidgets(
      'TEST C: search results expose Add-to-Selection without authentication',
      (tester) async {
        final container = makeContainer();
        final router = makeRouter(container);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        router.go(RoutePaths.customerSearchResults);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 400));

        // Real vehicle cards render with the add affordance.
        expect(find.text('Add'), findsWidgets);
        // No login redirect happened — we are still on the results route.
        expect(find.byType(SearchResultsScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );

    /// TEST D: trip details persist alongside the selection.
    test('TEST D: guest trip details persist alongside the selection', () {
      const trip = GuestTripDetails(
        pickupAddress: 'The Oberoi, New Delhi',
        destinationAddress: 'Grand Imperial, Gurugram',
        passengerCount: 8,
      );
      final sel = const GuestFleetSelection().withTrip(trip);
      expect(sel.trip.pickupAddress, 'The Oberoi, New Delhi');
      expect(sel.trip.hasAny, isTrue);
    });

    /// TEST E: the mandatory rule — selection SURVIVES login; cleared on logout.
    testWidgets(
      'TEST E: guest selection survives login and is cleared on logout',
      (tester) async {
        final container = makeContainer();
        final sel = container.read(guestFleetSelectionProvider.notifier);

        // Guest composes the fleet.
        sel.addType(
          vehicleTypeId: 'VT_THAR',
          displayName: 'Mahindra Thar',
          vehicleClass: 'Premium SUV',
          seatingCapacity: 5,
        );
        sel.setQuantity('VT_THAR', 2);
        sel.updateTrip(
          const GuestTripDetails(pickupAddress: 'Civil Lines, Delhi'),
        );

        // Login detour through the REAL controller flow (OTP lifecycle).
        final auth = container.read(authControllerProvider.notifier);
        final otpReq = await auth.requestOtp(phoneNumber: '+919812345678');
        expect(otpReq.isSuccess, isTrue);
        final otpState = container.read(authControllerProvider);
        expect(otpState, isA<OtpSent>());
        final verify = await auth.verifyOtp(
          otpSessionId: (otpState as OtpSent).otpSessionId,
          otpCode: '000000',
        );
        expect(verify.isSuccess, isTrue);
        await tester.pump();

        // The selection SURVIVED authentication.
        final afterLogin = container.read(guestFleetSelectionProvider);
        expect(
          afterLogin.containsType('VT_THAR'),
          isTrue,
          reason: 'selection must survive login',
        );
        expect(afterLogin.totalVehicles, 2);
        expect(afterLogin.trip.pickupAddress, 'Civil Lines, Delhi');
        expect(container.read(activeSessionProvider).isAuthenticated, isTrue);

        // Logout wipes it (shared-device hygiene).
        await auth.signOut();
        await tester.pump();
        expect(container.read(guestFleetSelectionProvider).isEmpty, isTrue);
      },
    );

    /// TEST F: guest search criteria survive sign-in (search is keepAlive too).
    testWidgets(
      'TEST F: search criteria survive the login detour',
      (tester) async {
        final container = makeContainer();
        container
            .read(searchControllerProvider.notifier)
            .updateQuery(const VehicleSearchQuery(
              pickupLocation: 'Delhi NCR',
              passengerCount: 8,
              occasionId: 'Baraat',
            ));
        await tester.pump(const Duration(milliseconds: 800));

        expect(container.read(activeSessionProvider).isAuthenticated, isFalse);

        // Login.
        final auth = container.read(authControllerProvider.notifier);
        await auth.requestOtp(phoneNumber: '+919812345678');
        final otpState = container.read(authControllerProvider);
        await auth.verifyOtp(
          otpSessionId: (otpState as OtpSent).otpSessionId,
          otpCode: '000000',
        );
        await tester.pump();

        final session = container.read(searchControllerProvider);
        expect(session.query.pickupLocation, 'Delhi NCR');
        expect(session.query.passengerCount, 8);
        expect(session.query.occasionId, 'Baraat');
      },
    );

    /// TEST G: the vehicle card renders the trust label + selection state.
    testWidgets(
      'TEST G: vehicle card shows verified-trust label and selection state',
      (tester) async {
        int? requestedQuantity;
        var removed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShadiVehicleCard(
                viewModel: const VehicleCardViewModel(
                  id: 'v1',
                  title: 'Toyota Innova Crysta',
                  subtitle: 'Executive MPV · 7 seats',
                  priceText: '₹25,000',
                  priceUnit: '/ day',
                  fareEstimateText: '₹25,000+',
                  isPremium: false,
                  hasVerifiedChauffeur: true,
                  isVerifiedVehicle: true,
                  isAvailable: true,
                ),
                onTap: () {},
                onAddToSelection: () {},
              ),
            ),
          ),
        );
        expect(
          find.text('Vehicle and chauffeur verified by ShadiDriver'),
          findsOneWidget,
        );
        // NOT SELECTED: the card offers the add action.
        expect(find.text('Add'), findsOneWidget);
        expect(find.text('Selected'), findsNothing);

        // SELECTED: the add action is gone (tapping it again would only
        // inflate the quantity) and the card exposes the shared line's
        // quantity with an explicit removal instead.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShadiVehicleCard(
                viewModel: const VehicleCardViewModel(
                  id: 'v1',
                  title: 'Toyota Innova Crysta',
                  subtitle: 'Executive MPV · 7 seats',
                  priceText: '₹25,000',
                  priceUnit: '/ day',
                  fareEstimateText: '₹25,000+',
                  isPremium: false,
                  hasVerifiedChauffeur: true,
                  isVerifiedVehicle: true,
                  isAvailable: true,
                ),
                onTap: () {},
                onAddToSelection: () {},
                isSelected: true,
                selectedQuantity: 2,
                onQuantityChanged: (q) => requestedQuantity = q,
                onRemoveSelection: () => removed = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Selected'), findsOneWidget);
        expect(find.text('Add to Selection'), findsNothing);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);

        // `+` asks for 3, `−` asks for 1 — the card never edits the model
        // itself, it only reports the requested quantity to the shared owner.
        await tester.tap(find.byTooltip('Increase quantity'));
        expect(requestedQuantity, 3);
        await tester.tap(find.byTooltip('Decrease quantity'));
        expect(requestedQuantity, 1);

        await tester.tap(find.text('Remove'));
        expect(removed, isTrue);
      },
    );

    /// TEST H: authenticated customer still reaches Customer Home (no
    /// regression to the authenticated startup path).
    testWidgets(
      'TEST H: authenticated customer reaches Customer Home from splash',
      (tester) async {
        final container = makeContainer();
        final router = makeRouter(container);
        await authRepo.devSignInAsRole(UserRole.customer);
        await container.read(authControllerProvider.notifier).restoreSession();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          router.routeInformationProvider.value.uri.path,
          RoutePaths.customerHome,
        );
        expect(find.byType(CustomerHomeScreen), findsOneWidget);
      },
    );

    /// TEST L: driver and admin still reach their consoles.
    test('TEST L: driver/admin sessions resolve to their own consoles', () {
      expect(ShadiRouteGuard.getRoleHome('driver'), '/driver');
      expect(ShadiRouteGuard.getRoleHome('fleetOwner'), '/driver');
      expect(ShadiRouteGuard.getRoleHome('operationsAdmin'), '/admin');
    });
  });

  group('GUEST-FIRST ENTRY — real-mode API contract', () {
    test(
      'TEST I: real-mode wire contract carries vehicle_type_id for selection',
      () {
        // The public vehicle payload is the guest browsing source of truth.
        // The mapper must surface vehicle_type_id so guest selection references
        // the BOOKABLE type, not a specific plate.
        final payload = <String, dynamic>{
          'id': '9f1c',
          'vehicle_type_id': 'VT_INNOVA_CRYSTA',
          'fleet_code': 'FLR-INN-01',
          'make': 'Toyota',
          'model': 'Innova Crysta',
          'year': 2023,
          'vehicle_class': 'EXECUTIVE_MPV',
          'seating_capacity': 6,
          'verification_status': 'APPROVED',
          'is_available': true,
          'has_verified_chauffeur': true,
          'amenities': ['Dual AC'],
          'price_indicator_paise': '2500000',
        };
        final summary = PublicVehicleDto.toSummary(payload);
        expect(summary.vehicleTypeId, 'VT_INNOVA_CRYSTA');
        expect(summary.seatingCapacity, 6);
      },
    );

    test(
      'TEST J: real-mode vehicle discovery performs an HTTP GET without a token',
      () async {
        String? seenPath;
        final adapter = _FakeAdapter(
          onRequest: (options) {
            seenPath = options.uri.path;
            expect(
              options.headers.containsKey('authorization'),
              isFalse,
              reason: 'guest browsing must not require a JWT',
            );
            return jsonEncode({
              'success': true,
              'data': {
                'items': [
                  {
                    'id': 'veh-1',
                    'vehicle_type_id': 'VT_INNOVA_CRYSTA',
                    'make': 'Toyota',
                    'model': 'Innova Crysta',
                    'year': 2023,
                    'vehicle_class': 'EXECUTIVE_MPV',
                    'seating_capacity': 6,
                    'verification_status': 'APPROVED',
                    'is_available': true,
                    'has_verified_chauffeur': true,
                  },
                ],
              },
            });
          },
        );

        final client = ApiClient(
          config: EnvironmentConfig.development(
            apiBaseUrlOverride: 'http://localhost:3000/api',
          ),
          logger: _SilentLogger(),
          secureStorage: InMemorySecureStorage(),
          dio: Dio()..httpClientAdapter = adapter,
        );

        final response = await client.get<Map<String, dynamic>>('/v1/vehicles');
        expect(seenPath, '/api/v1/vehicles');
        final envelope = ApiEnvelope.fromJson(response.data);
        expect(envelope.success, isTrue);
      },
    );

    test(
      'TEST K: the real wire format never carries chauffeur identity',
      () {
        const privateKeys = [
          'driver_phone',
          'driver_email',
          'driver_address',
          'chauffeur_phone_number',
          'phone_number',
          'internal_notes',
          'registration_number',
        ];
        // The public contract field list defines what MAY appear. None of the
        // private keys may be part of the customer wire contract.
        for (final key in privateKeys) {
          expect(
            PublicVehicleDto.contractFields.contains(key),
            isFalse,
            reason: '$key must never be part of the public vehicle contract',
          );
        }
      },
    );
  });
}

// -----------------------------------------------------------------------------
// Test support
// -----------------------------------------------------------------------------

/// Minimal dio adapter: records requests, answers from a canned JSON body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.onRequest});

  final String Function(RequestOptions options) onRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      onRequest(options),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _SilentLogger implements AppLogger {
  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void warning(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}
}
