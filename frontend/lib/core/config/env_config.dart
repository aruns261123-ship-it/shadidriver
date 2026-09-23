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

  /// Default development configuration. Defaults to the REAL backend path
  /// (useMockData=false); SHADI_USE_MOCK_AUTH=true opts into mock mode for
  /// offline UI development and automated tests only.
  factory EnvironmentConfig.development({
    bool? useMockData,
    String? apiBaseUrlOverride,
  }) {
    const isMock = bool.fromEnvironment(
      'SHADI_USE_MOCK_AUTH',
      defaultValue: false,
    );
    return EnvironmentConfig(
      flavor: AppFlavor.development,
      appName: 'ShadiDriver Dev',
      apiBaseUrl:
          apiBaseUrlOverride ?? const String.fromEnvironment('SHADI_API_BASE_URL'),
      wsBaseUrl: 'wss://dev-api.shadidriver.in/ws',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      enableNetworkLogging: true,
      useMockData: useMockData ?? isMock,
    );
  }

  /// Staging configuration for pre-release validation.
  factory EnvironmentConfig.staging({bool? useMockData}) {
    const isMock = bool.fromEnvironment(
      'SHADI_USE_MOCK_AUTH',
      defaultValue: false,
    );
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
}
