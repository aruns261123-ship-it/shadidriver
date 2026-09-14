import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_placeholder_screen.dart';
import '../../features/drivers/presentation/driver_home_placeholder_screen.dart';
import '../../features/home/presentation/customer_home_placeholder_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/profile/presentation/admin_placeholder_screen.dart';
import 'route_guards.dart';
import 'route_paths.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Creates the centralized [GoRouter] instance.
GoRouter createShadiRouter({
  String initialLocation = RoutePaths.splash,
  RouteGuard routeGuard = const ShadiRouteGuard(),
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: (BuildContext context, GoRouterState state) async {
      return await routeGuard.evaluateRedirect(
        targetLocation: state.matchedLocation,
        isAuthenticated: false,
        userRole: null,
      );
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: 'auth',
        builder: (context, state) => const AuthPlaceholderScreen(),
      ),
      GoRoute(
        path: RoutePaths.customer,
        name: 'customer',
        builder: (context, state) => const CustomerHomePlaceholderScreen(),
      ),
      GoRoute(
        path: RoutePaths.driver,
        name: 'driver',
        builder: (context, state) => const DriverHomePlaceholderScreen(),
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: 'admin',
        builder: (context, state) => const AdminPlaceholderScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
}
