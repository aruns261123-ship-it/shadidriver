import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/router/app_router.dart';
import 'package:shadidriver/app/router/route_guards.dart';
import 'package:shadidriver/app/router/route_paths.dart';

void main() {
  group('GoRouter & Route Configuration Tests', () {
    test('RoutePaths are non-empty and well-formed', () {
      expect(RoutePaths.splash, equals('/splash'));
      expect(RoutePaths.auth, equals('/auth'));
      expect(RoutePaths.customer, equals('/customer'));
      expect(RoutePaths.driver, equals('/driver'));
      expect(RoutePaths.admin, equals('/admin'));
    });

    test('createShadiRouter instantiates GoRouter without error', () {
      final router = createShadiRouter();
      expect(router, isNotNull);
      expect(router.configuration.routes.length, greaterThanOrEqualTo(5));
    });

    test(
      'ShadiRouteGuard allows routes in Phase 0 default configuration',
      () async {
        const guard = ShadiRouteGuard();
        final redirect = await guard.evaluateRedirect(
          targetLocation: RoutePaths.customer,
          isAuthenticated: false,
          userRole: null,
        );

        expect(redirect, isNull);
      },
    );
  });
}
