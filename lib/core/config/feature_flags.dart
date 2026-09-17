/// Compile-time feature flags for ShadiDriver.
///
/// These are resolved from `--dart-define` values at build time, so a single
/// codebase can run against mock repositories (default, for frontend-only
/// development while the backend is being built in parallel) or the real
/// backend, without changing any Dart source.
///
/// Usage:
///   flutter run --dart-define=USE_MOCK_REPOSITORIES=false
///
/// Per-feature overrides let the frontend dev flip ONE feature over to the
/// real backend (e.g. auth, once the backend partner ships it) while every
/// other feature keeps using mocks — this is the recommended way to
/// integrate feature-by-feature instead of a single big-bang cutover.
abstract final class FeatureFlags {
  /// Global default: true = use mock repositories everywhere.
  /// Flip to false once the backend is generally ready.
  static const bool useMockRepositoriesByDefault = bool.fromEnvironment(
    'USE_MOCK_REPOSITORIES',
    defaultValue: true,
  );

  /// Per-feature overrides. Each defaults to [useMockRepositoriesByDefault]
  /// so you only need to pass the flags for features you're actively
  /// cutting over, e.g.:
  ///   flutter run --dart-define=USE_MOCK_REPOSITORIES=true --dart-define=USE_MOCK_AUTH=false
  static const bool useMockAuth = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: useMockRepositoriesByDefault,
  );

  static const bool useMockBookings = bool.fromEnvironment(
    'USE_MOCK_BOOKINGS',
    defaultValue: useMockRepositoriesByDefault,
  );

  static const bool useMockDrivers = bool.fromEnvironment(
    'USE_MOCK_DRIVERS',
    defaultValue: useMockRepositoriesByDefault,
  );

  static const bool useMockVehicles = bool.fromEnvironment(
    'USE_MOCK_VEHICLES',
    defaultValue: useMockRepositoriesByDefault,
  );

  static const bool useMockPayments = bool.fromEnvironment(
    'USE_MOCK_PAYMENTS',
    defaultValue: useMockRepositoriesByDefault,
  );

  static const bool useMockNotifications = bool.fromEnvironment(
    'USE_MOCK_NOTIFICATIONS',
    defaultValue: useMockRepositoriesByDefault,
  );

  // Add one flag per remaining repository (services, trips, reviews,
  // support, urgent_dispatch, profile-related repos) following the same
  // pattern as you build each Http*Repository implementation.
}
