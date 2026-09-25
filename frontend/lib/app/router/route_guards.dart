import '../../features/auth/domain/entities/account_status.dart';

/// Architecture-ready route guard interface.
/// Evaluates access permissions during route transitions without hardcoding logic into widgets.
abstract interface class RouteGuard {
  /// Returns a redirect route string if access should be denied or redirected, or null to allow.
  Future<String?> evaluateRedirect({
    required String targetLocation,
    required bool isAuthenticated,
    required String? userRole,
    AccountStatus? accountStatus,
  });
}

/// Default architecture-ready route guard implementation.
/// Evaluates access permissions during route transitions.
///
/// Authentication is required only for *transactional* surfaces. Browsing the
/// catalog - home, search, search results, vehicle details - is deliberately
/// open to signed-out visitors, because a customer must never have to create
/// an account just to look at cars. The rule is fail-closed: a path is public
/// only when it appears in [publicPaths] or [publicPathPrefixes], so a newly
/// added route is protected by default.
class ShadiRouteGuard implements RouteGuard {
  final bool enforceAuth;

  const ShadiRouteGuard({this.enforceAuth = false});

  /// Exact locations a signed-out visitor may reach.
  static const Set<String> publicPaths = <String>{
    '/',
    '',
    '/splash',
    '/auth',
    '/account-suspended',
    // Customer browsing surface.
    '/customer',
    '/customer/home',
  };

  /// Prefix-matched public surfaces (vehicle details, search + its results).
  static const List<String> publicPathPrefixes = <String>[
    '/customer/search',
    '/customer/vehicles/',
  ];

  /// TRUE when [location] is a browsable surface that needs no session.
  static bool isPublicLocation(String location) {
    if (publicPaths.contains(location)) return true;
    return publicPathPrefixes.any(location.startsWith);
  }

  /// Builds the sign-in redirect while preserving where the visitor was going,
  /// so a guest who was building a booking returns to it after authenticating.
  ///
  /// Only customer transactional paths are preserved. Console paths are not:
  /// a visitor who is not signed in has no proven role, so sending them to
  /// `/driver` or `/admin` after sign-in would be meaningless — and the login
  /// screen deliberately ignores any redirect outside `/customer/`.
  static String signInRedirectFor(String targetLocation) {
    if (!targetLocation.startsWith('/customer/') ||
        isPublicLocation(targetLocation)) {
      return '/auth';
    }
    return '/auth?redirect=${Uri.encodeComponent(targetLocation)}';
  }

  @override
  Future<String?> evaluateRedirect({
    required String targetLocation,
    required bool isAuthenticated,
    required String? userRole,
    AccountStatus? accountStatus,
  }) async {
    // 1. Splash screen and root are always accessible
    if (targetLocation == '/splash' ||
        targetLocation == '/' ||
        targetLocation.isEmpty) {
      return null;
    }

    // 2. Unauthenticated access handling
    if (!isAuthenticated) {
      if (targetLocation == '/auth') {
        return null;
      }
      // Browsing is open to guests regardless of how strictly auth is enforced.
      if (isPublicLocation(targetLocation)) {
        return null;
      }
      if (enforceAuth) {
        return signInRedirectFor(targetLocation);
      }
      // If auth is not enforced and no specific role is present, allow access
      if (userRole == null) {
        return null;
      }
    }

    // 3. Authenticated user visiting /auth is redirected to their role home
    if (targetLocation == '/auth' && isAuthenticated) {
      if (accountStatus == AccountStatus.suspended) {
        return '/account-suspended';
      }
      if (accountStatus == AccountStatus.profileIncomplete) {
        return _isDriverRole(userRole ?? '')
            ? '/driver/profile/edit'
            : '/customer/profile/edit';
      }
      return getRoleHome(userRole);
    }

    // 4. Suspended account handling
    if (isAuthenticated && accountStatus == AccountStatus.suspended) {
      if (targetLocation == '/account-suspended') {
        return null;
      }
      return '/account-suspended';
    }

    // 5. Incomplete profile handling
    if (isAuthenticated && accountStatus == AccountStatus.profileIncomplete) {
      final isDriver = _isDriverRole(userRole ?? '');
      final requiredProfilePath = isDriver
          ? '/driver/profile/edit'
          : '/customer/profile/edit';
      if (targetLocation == requiredProfilePath) {
        return null;
      }
      return requiredProfilePath;
    }

    // 6. Strict Role-Based Isolation
    if (userRole != null) {
      final isCustomer = _isCustomerRole(userRole);
      final isDriver = _isDriverRole(userRole);
      final isAdmin = _isAdminRole(userRole);

      if (isCustomer) {
        // Customer cannot access driver or admin consoles
        if (targetLocation.startsWith('/driver') ||
            targetLocation.startsWith('/admin')) {
          return '/customer';
        }
      } else if (isDriver) {
        // Driver cannot access customer home or admin consoles
        if (targetLocation.startsWith('/customer') ||
            targetLocation.startsWith('/admin')) {
          return '/driver';
        }
      } else if (isAdmin) {
        // Admin cannot access customer home or driver consoles
        if (targetLocation.startsWith('/customer') ||
            targetLocation.startsWith('/driver')) {
          return '/admin';
        }
      }
    }

    return null;
  }

  /// Resolves the home route for a given role identifier.
  static String getRoleHome(String? role) {
    if (role == null) return '/customer';
    if (_isDriverRole(role)) return '/driver';
    if (_isAdminRole(role)) return '/admin';
    return '/customer';
  }

  static bool _isCustomerRole(String role) {
    return role == 'customer';
  }

  static bool _isDriverRole(String role) {
    return role == 'driver' || role == 'fleetOwner' || role == 'fleet_owner';
  }

  static bool _isAdminRole(String role) {
    return role == 'operationsAdmin' ||
        role == 'verificationAdmin' ||
        role == 'financeAdmin' ||
        role == 'superAdmin' ||
        role == 'operations_admin' ||
        role == 'verification_admin' ||
        role == 'finance_admin' ||
        role == 'super_admin' ||
        role == 'admin';
  }
}
