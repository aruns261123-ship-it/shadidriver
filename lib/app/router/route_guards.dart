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
    if (!enforceAuth) {
      return null;
    }

    // Unauthenticated access to protected routes
    if (!isAuthenticated &&
        targetLocation != '/auth' &&
        targetLocation != '/splash') {
      return '/auth';
    }

    // Admin routes require admin role
    if (targetLocation.startsWith('/admin')) {
      final isAdmin =
          userRole == 'operationsAdmin' ||
          userRole == 'verificationAdmin' ||
          userRole == 'financeAdmin' ||
          userRole == 'superAdmin';
      if (!isAdmin) return '/customer';
    }

    // Driver routes require driver role
    if (targetLocation.startsWith('/driver')) {
      final isDriver = userRole == 'driver' || userRole == 'fleetOwner';
      if (!isDriver) return '/customer';
    }

    return null;
  }
}
