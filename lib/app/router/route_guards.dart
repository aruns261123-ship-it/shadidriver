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

/// Default architecture-ready route guard implementation for Phase 0.
/// Does not block routes during foundation phase, but provides the evaluation hook.
class ShadiRouteGuard implements RouteGuard {
  const ShadiRouteGuard();

  @override
  Future<String?> evaluateRedirect({
    required String targetLocation,
    required bool isAuthenticated,
    required String? userRole,
  }) async {
    // Architecture hook ready for Phase 1 session enforcement
    return null;
  }
}
