import 'flavor.dart';

/// Immutable environment configuration for ShadiDriver.
/// Backend endpoints and API parameters are supplied through this configuration
/// rather than being hardcoded in business logic.
class EnvironmentConfig {
  final AppFlavor flavor;
  final String appName;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableNetworkLogging;
  final String apiVersion;
  final bool useMockData;

  const EnvironmentConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.enableNetworkLogging = true,
    this.apiVersion = 'v1',
    this.useMockData = true,
  });

  /// Default development configuration pointing to mock/local environment.
  factory EnvironmentConfig.development({bool? useMockData}) {
    const isMock =
        bool.fromEnvironment('SHADI_USE_MOCK_AUTH', defaultValue: true);
    return EnvironmentConfig(
      flavor: AppFlavor.development,
      appName: 'ShadiDriver Dev',
      apiBaseUrl: const String.fromEnvironment(
        'SHADI_API_BASE_URL',
        defaultValue: 'https://dev-api.shadidriver.in',
      ),
      wsBaseUrl: 'wss://dev-api.shadidriver.in/ws',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      enableNetworkLogging: true,
      useMockData: useMockData ?? isMock,
    );
  }

  /// Staging configuration for pre-release validation.
  factory EnvironmentConfig.staging({bool? useMockData}) {
    const isMock =
        bool.fromEnvironment('SHADI_USE_MOCK_AUTH', defaultValue: false);
    return EnvironmentConfig(
      flavor: AppFlavor.staging,
      appName: 'ShadiDriver Staging',
      apiBaseUrl: const String.fromEnvironment(
        'SHADI_API_BASE_URL',
        defaultValue: 'https://staging-api.shadidriver.in',
      ),
      wsBaseUrl: 'wss://staging-api.shadidriver.in/ws',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      enableNetworkLogging: true,
      useMockData: useMockData ?? isMock,
    );
  }

  /// Production configuration adhering to strict security and telemetry standards.
  factory EnvironmentConfig.production({bool? useMockData}) {
    return const EnvironmentConfig(
      flavor: AppFlavor.production,
      appName: 'ShadiDriver',
      apiBaseUrl: String.fromEnvironment(
        'SHADI_API_BASE_URL',
        defaultValue: 'https://api.shadidriver.in',
      ),
      wsBaseUrl: 'wss://api.shadidriver.in/ws',
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      enableNetworkLogging: false,
      useMockData: false,
    );
  }

  /// Resolves the active environment from a compile-time `--dart-define`.
  ///
  /// Usage:
  ///   flutter run --dart-define=APP_FLAVOR=staging
  ///   flutter build appbundle --dart-define=APP_FLAVOR=production
  ///
  /// Defaults to development when no flavor is supplied, so a plain
  /// `flutter run` during day-to-day frontend work keeps working unchanged.
  /// This is the single switch point for which backend the app targets —
  /// nothing else in the app should read `String.fromEnvironment` directly.
  factory EnvironmentConfig.current() {
    const flavorName = String.fromEnvironment(
      'APP_FLAVOR',
      defaultValue: 'development',
    );
    return switch (flavorName) {
      'staging' => EnvironmentConfig.staging(),
      'production' => EnvironmentConfig.production(),
      _ => EnvironmentConfig.development(),
    };
  }
}
