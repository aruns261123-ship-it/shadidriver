import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/account_status.dart';
import '../../features/auth/presentation/account_suspended_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/drivers/presentation/driver_active_trip_screen.dart';
import '../../features/drivers/presentation/driver_booking_request_screen.dart';
import '../../features/drivers/presentation/driver_dashboard_screen.dart';
import '../../features/home/presentation/customer_home_screen.dart';
import '../../features/home/presentation/customer_home_shell.dart';
import '../../features/home/presentation/customer_tabs_placeholder.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/search/presentation/search_results_screen.dart';
import '../../features/vehicles/presentation/vehicle_details_screen.dart';
import '../../features/drivers/presentation/chauffeur_profile_screen.dart';
import '../../features/bookings/presentation/booking_entry_screen.dart';
import '../../features/bookings/presentation/booking_review_screen.dart';
import '../../features/bookings/presentation/booking_result_screen.dart';
import '../../features/bookings/presentation/customer_bookings_screen.dart';
import '../../features/home/presentation/splash_screen.dart';
import '../../features/profile/presentation/admin_dashboard_screen.dart';
import '../../features/profile/presentation/customer_account_center_screen.dart';
import '../../features/profile/presentation/customer_edit_profile_screen.dart';
import '../../features/profile/presentation/saved_addresses_screen.dart';
import '../../features/drivers/presentation/driver_account_center_screen.dart';
import '../../features/drivers/presentation/driver_edit_profile_screen.dart';
import '../../features/profile/presentation/admin_account_center_screen.dart';
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
  bool Function()? isAuthenticated,
  String? Function()? userRole,
  AccountStatus Function()? accountStatus,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.matchedLocation.isNotEmpty
          ? state.matchedLocation
          : state.uri.path;
      return await routeGuard.evaluateRedirect(
        targetLocation: loc,
        isAuthenticated: isAuthenticated?.call() ?? false,
        userRole: userRole?.call(),
        accountStatus: accountStatus?.call(),
      );
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => RoutePaths.splash,
      ),
      GoRoute(
        path: RoutePaths.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.auth,
        name: 'auth',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.accountSuspended,
        name: 'accountSuspended',
        builder: (context, state) => const AccountSuspendedScreen(),
      ),
      ShellRoute(
        navigatorKey: _customerShellNavigatorKey,
        builder: (context, state, child) => CustomerHomeShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.customer,
            redirect: (_, __) => RoutePaths.customerHome,
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
            builder: (context, state) => const CustomerBookingsScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerMessages,
            name: 'customerMessages',
            builder: (context, state) => const CustomerMessagesPlaceholder(),
          ),
          GoRoute(
            path: RoutePaths.customerProfile,
            name: 'customerProfile',
            builder: (context, state) => const CustomerAccountCenterScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerProfileEdit,
            name: 'customerProfileEdit',
            builder: (context, state) => const CustomerEditProfileScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerAddresses,
            name: 'customerAddresses',
            builder: (context, state) => const SavedAddressesScreen(),
          ),
          GoRoute(
            path: RoutePaths.customerVehicleDetails,
            name: 'customerVehicleDetails',
            builder: (context, state) => VehicleDetailsScreen(
              vehicleId: state.pathParameters['vehicleId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.customerChauffeurProfile,
            name: 'customerChauffeurProfile',
            builder: (context, state) => ChauffeurProfileScreen(
              chauffeurId: state.pathParameters['chauffeurId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.customerBookingCreate,
            name: 'customerBookingCreate',
            builder: (context, state) => BookingEntryScreen(
              vehicleId: state.pathParameters['vehicleId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.customerBookingReview,
            name: 'customerBookingReview',
            builder: (context, state) => BookingReviewScreen(
              draftId: state.pathParameters['draftId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.customerBookingResult,
            name: 'customerBookingResult',
            builder: (context, state) => BookingResultScreen(
              bookingId: state.pathParameters['bookingId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.driver,
        name: 'driver',
        builder: (context, state) => const DriverDashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            name: 'driverProfile',
            builder: (context, state) => const DriverAccountCenterScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                name: 'driverProfileEdit',
                builder: (context, state) => const DriverEditProfileScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'requests/:bookingId',
            name: 'driverRequestDetails',
            builder: (context, state) => DriverBookingRequestScreen(
              bookingId: state.pathParameters['bookingId'] ?? '',
            ),
          ),
          GoRoute(
            path: 'active-trip/:bookingId',
            name: 'driverActiveTrip',
            builder: (context, state) => DriverActiveTripScreen(
              bookingId: state.pathParameters['bookingId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: RoutePaths.admin,
        name: 'admin',
        builder: (context, state) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            name: 'adminProfile',
            builder: (context, state) => const AdminAccountCenterScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
}
