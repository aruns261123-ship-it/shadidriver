/// Architecture-ready route guard interface.
/// Evaluates access permissions during route transitions without hardcoding logic into widgets.
abstract interface class RouteGuard {
  /// Returns a redirect route string if access should be denied or redirected, or null to allow.
  Future<String?> evaluateRedirect({
    required String targetLocation,
    required bool isAuthenticated,
    required String? userRole,
  });
}

/// Default architecture-ready route guard implementation.
/// Evaluates access permissions during route transitions.
class ShadiRouteGuard implements RouteGuard {
  final bool enforceAuth;

  const ShadiRouteGuard({this.enforceAuth = false});

  @override
  Future<String?> evaluateRedirect({
    required String targetLocation,
    required bool isAuthenticated,
    required String? userRole,
  }) async {
    // 1. Splash screen is always accessible
    if (targetLocation == '/splash') {
      return null;
    }

    // 2. Unauthenticated access handling
    if (!isAuthenticated) {
      if (targetLocation == '/auth') {
        return null;
      }
      if (enforceAuth) {
        return '/auth';
      }
      // If auth is not enforced and no specific role is present, allow access
      if (userRole == null) {
        return null;
      }
    }

    // 3. Authenticated user visiting /auth is redirected to their role home
    if (targetLocation == '/auth' && isAuthenticated) {
      return getRoleHome(userRole);
    }

    // 4. Strict Role-Based Isolation
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
    return role == 'driver' ||
        role == 'fleetOwner' ||
        role == 'fleet_owner';
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
