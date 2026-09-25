import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/router/route_guards.dart';
import 'package:shadidriver/app/router/route_paths.dart';

void main() {
  group('ShadiRouteGuard Role Isolation & Security Tests', () {
    const defaultGuard = ShadiRouteGuard(enforceAuth: false);
    const strictAuthGuard = ShadiRouteGuard(enforceAuth: true);

    group('Public Routes & Unauthenticated Access', () {
      test(
        'Splash screen is always accessible regardless of auth state or role',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.splash,
              isAuthenticated: false,
              userRole: null,
            ),
            isNull,
          );

          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.splash,
              isAuthenticated: false,
              userRole: null,
            ),
            isNull,
          );

          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.splash,
              isAuthenticated: true,
              userRole: 'customer',
            ),
            isNull,
          );
        },
      );

      test('Auth screen is accessible when unauthenticated', () async {
        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.auth,
            isAuthenticated: false,
            userRole: null,
          ),
          isNull,
        );

        expect(
          await strictAuthGuard.evaluateRedirect(
            targetLocation: RoutePaths.auth,
            isAuthenticated: false,
            userRole: null,
          ),
          isNull,
        );
      });

      test(
        'Unauthenticated user is redirected to /auth when enforceAuth is true',
        () async {
          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.driver,
              isAuthenticated: false,
              userRole: null,
            ),
            equals(RoutePaths.auth),
          );

          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.admin,
              isAuthenticated: false,
              userRole: null,
            ),
            equals(RoutePaths.auth),
          );

          // Transactional customer surfaces are protected and remember where
          // the visitor was going.
          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.customerBookings,
              isAuthenticated: false,
              userRole: null,
            ),
            equals(
              '/auth?redirect='
              '${Uri.encodeComponent(RoutePaths.customerBookings)}',
            ),
          );
        },
      );

      test(
        'The customer shell is browsable without an account (vehicle-first)',
        () async {
          for (final location in <String>[
            RoutePaths.customer,
            RoutePaths.customerHome,
            RoutePaths.customerSearch,
            RoutePaths.customerSearchResults,
            RoutePaths.customerVehicleDetailsPath('v1'),
          ]) {
            expect(
              await strictAuthGuard.evaluateRedirect(
                targetLocation: location,
                isAuthenticated: false,
                userRole: null,
              ),
              isNull,
              reason: '$location must not require authentication',
            );
          }
        },
      );

      test(
        'Authenticated user landing on /auth is redirected to their role home',
        () async {
          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.auth,
              isAuthenticated: true,
              userRole: 'customer',
            ),
            equals(RoutePaths.customer),
          );

          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.auth,
              isAuthenticated: true,
              userRole: 'driver',
            ),
            equals(RoutePaths.driver),
          );

          expect(
            await strictAuthGuard.evaluateRedirect(
              targetLocation: RoutePaths.auth,
              isAuthenticated: true,
              userRole: 'operationsAdmin',
            ),
            equals(RoutePaths.admin),
          );
        },
      );
    });

    group('Customer Role Isolation Invariants', () {
      test('Customer can access all customer routes', () async {
        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.customer,
            isAuthenticated: true,
            userRole: 'customer',
          ),
          isNull,
        );

        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.customerHome,
            isAuthenticated: true,
            userRole: 'customer',
          ),
          isNull,
        );

        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.customerProfile,
            isAuthenticated: true,
            userRole: 'customer',
          ),
          isNull,
        );
      });

      test(
        'Customer is blocked from driver routes and redirected to /customer',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.driver,
              isAuthenticated: true,
              userRole: 'customer',
            ),
            equals(RoutePaths.customer),
          );

          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: '/driver/active-trip/123',
              isAuthenticated: true,
              userRole: 'customer',
            ),
            equals(RoutePaths.customer),
          );
        },
      );

      test(
        'Customer is blocked from admin routes and redirected to /customer',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.admin,
              isAuthenticated: true,
              userRole: 'customer',
            ),
            equals(RoutePaths.customer),
          );

          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.adminProfile,
              isAuthenticated: true,
              userRole: 'customer',
            ),
            equals(RoutePaths.customer),
          );
        },
      );
    });

    group('Driver Role Isolation Invariants', () {
      test('Driver can access driver routes', () async {
        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.driver,
            isAuthenticated: true,
            userRole: 'driver',
          ),
          isNull,
        );

        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.driverProfile,
            isAuthenticated: true,
            userRole: 'driver',
          ),
          isNull,
        );
      });

      test(
        'Driver is blocked from customer routes and redirected to /driver',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.customer,
              isAuthenticated: true,
              userRole: 'driver',
            ),
            equals(RoutePaths.driver),
          );

          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.customerHome,
              isAuthenticated: true,
              userRole: 'driver',
            ),
            equals(RoutePaths.driver),
          );

          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.customerProfile,
              isAuthenticated: true,
              userRole: 'driver',
            ),
            equals(RoutePaths.driver),
          );
        },
      );

      test(
        'Driver is blocked from admin routes and redirected to /driver',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.admin,
              isAuthenticated: true,
              userRole: 'driver',
            ),
            equals(RoutePaths.driver),
          );
        },
      );
    });

    group('Admin Role Isolation Invariants', () {
      test('Admin can access admin routes', () async {
        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.admin,
            isAuthenticated: true,
            userRole: 'operationsAdmin',
          ),
          isNull,
        );

        expect(
          await defaultGuard.evaluateRedirect(
            targetLocation: RoutePaths.adminProfile,
            isAuthenticated: true,
            userRole: 'superAdmin',
          ),
          isNull,
        );
      });

      test(
        'Admin is blocked from customer routes and redirected to /admin',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.customer,
              isAuthenticated: true,
              userRole: 'operationsAdmin',
            ),
            equals(RoutePaths.admin),
          );

          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.customerHome,
              isAuthenticated: true,
              userRole: 'verificationAdmin',
            ),
            equals(RoutePaths.admin),
          );
        },
      );

      test(
        'Admin is blocked from driver routes and redirected to /admin',
        () async {
          expect(
            await defaultGuard.evaluateRedirect(
              targetLocation: RoutePaths.driver,
              isAuthenticated: true,
              userRole: 'operationsAdmin',
            ),
            equals(RoutePaths.admin),
          );
        },
      );
    });
  });
}
