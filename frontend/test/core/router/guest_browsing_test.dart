import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_guards.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  const strictGuard = ShadiRouteGuard(enforceAuth: true);

  Future<String?> decide(String location) => strictGuard.evaluateRedirect(
    targetLocation: location,
    isAuthenticated: false,
    userRole: null,
  );

  group('a signed-out visitor may browse the catalog', () {
    test('catalog surfaces are reachable without an account', () async {
      for (final location in <String>[
        RoutePaths.customerHome,
        RoutePaths.customer,
        RoutePaths.customerSearch,
        RoutePaths.customerSearchResults,
        RoutePaths.customerVehicleDetailsPath('v1'),
        RoutePaths.splash,
        RoutePaths.auth,
      ]) {
        expect(
          await decide(location),
          isNull,
          reason: '$location must be browsable without authenticating',
        );
      }
    });

    test('public surfaces stay public even with the strictest auth setting',
        () async {
      // enforceAuth is on for every other path, so this proves the public
      // allow-list is what lets browsing through.
      expect(ShadiRouteGuard.isPublicLocation('/customer/search/results'), isTrue);
      expect(ShadiRouteGuard.isPublicLocation('/customer/vehicles/abc'), isTrue);
    });
  });

  group('transactional surfaces require a session', () {
    test('booking, favourites, profile and history bounce to sign-in', () async {
      for (final location in <String>[
        '/customer/bookings',
        '/customer/bookings/create/v1',
        '/customer/group-booking',
        '/customer/profile',
        '/customer/profile/edit',
        '/customer/addresses',
        '/customer/favorites',
      ]) {
        final redirect = await decide(location);
        expect(redirect, isNotNull, reason: '$location must require auth');
        expect(redirect, startsWith('/auth'));
      }
    });

    test('the sign-in redirect preserves where the guest was heading', () async {
      final redirect = await decide('/customer/bookings/create/v1');
      // A guest who tapped Book returns to the same vehicle afterwards instead
      // of re-selecting it.
      expect(
        redirect,
        '/auth?redirect=${Uri.encodeComponent('/customer/bookings/create/v1')}',
      );
    });

    test('public locations never carry a redirect parameter', () async {
      expect(
        ShadiRouteGuard.signInRedirectFor('/customer/search'),
        '/auth',
      );
    });
  });

  group('role isolation is unchanged for signed-in users', () {
    test('a customer is still kept out of the driver and admin consoles',
        () async {
      expect(
        await strictGuard.evaluateRedirect(
          targetLocation: '/driver',
          isAuthenticated: true,
          userRole: 'customer',
        ),
        '/customer',
      );
      expect(
        await strictGuard.evaluateRedirect(
          targetLocation: '/admin',
          isAuthenticated: true,
          userRole: 'customer',
        ),
        '/customer',
      );
    });
  });

  group('guest browsing renders end to end', () {
    Widget guestApp({required String initialLocation}) {
      final router = createShadiRouter(
        initialLocation: initialLocation,
        routeGuard: strictGuard,
        isAuthenticated: () => false,
      );
      return ProviderScope(
        overrides: [
          vehicleRepositoryProvider.overrideWithValue(MockVehicleRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('a signed-out visitor can open a vehicle page', (tester) async {
      await tester.pumpWidget(
        guestApp(initialLocation: RoutePaths.customerVehicleDetailsPath('v2')),
      );
      await tester.pumpAndSettle();

      // The catalog renders for a guest; no sign-in wall appears.
      expect(find.text('Audi A6'), findsWidgets);
      expect(find.text('Book Now'), findsOneWidget);
      expect(find.text('Assigned Chauffeur'), findsNothing);
    });

    testWidgets('a signed-out visitor tapping into booking is asked to sign in',
        (tester) async {
      await tester.pumpWidget(
        guestApp(initialLocation: '/customer/bookings/create/v2'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Book Now'), findsNothing);
      // Landed on the authentication screen instead.
      expect(find.text('Welcome to ShadiDriver'), findsOneWidget);
    });
  });
}
