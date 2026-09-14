import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_placeholder_screen.dart';
import '../../features/drivers/presentation/driver_home_placeholder_screen.dart';
import '../../features/home/presentation/customer_home_screen.dart';
import '../../features/home/presentation/customer_home_shell.dart';
import '../../features/home/presentation/customer_tabs_placeholder.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/profile/presentation/admin_placeholder_screen.dart';
import 'route_guards.dart';
import 'route_paths.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _customerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerShell');

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
      // Customer Portal with Shell for Bottom Navigation
      ShellRoute(
        navigatorKey: _customerShellNavigatorKey,
        builder: (context, state, child) => CustomerHomeShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.customer,
            redirect: (_, _) => RoutePaths.customerHome,
          ),
          GoRoute(
            path: RoutePaths.customerHome,
            name: 'customerHome',
            builder: (context, state) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerSearch,
            name: 'customerSearch',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerSearchResults,
            name: 'customerSearchResults',
            builder: (context, state) => const SearchResultsScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerBookings,
            name: 'customerBookings',
            builder: (context, state) => const CustomerBookingsPlaceholder(),
          ),
          GoRoute(
            path: RoutePaths.customerMessages,
            name: 'customerMessages',
            builder: (context, state) => const CustomerMessagesPlaceholder(),
          ),
          GoRoute(
            path: RoutePaths.customerProfile,
            name: 'customerProfile',
            builder: (context, state) => const CustomerProfilePlaceholder(),
          ),
        ],
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
