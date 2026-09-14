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

  const EnvironmentConfig({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.enableNetworkLogging = true,
    this.apiVersion = 'v1',
  });

  /// Default development configuration pointing to mock/local environment.
  factory EnvironmentConfig.development() {
    return const EnvironmentConfig(
      flavor: AppFlavor.development,
      appName: 'ShadiDriver Dev',
      apiBaseUrl: 'https://dev-api.shadidriver.in',
      wsBaseUrl: 'wss://dev-api.shadidriver.in/ws',
      connectTimeout: Duration(seconds: 20),
      receiveTimeout: Duration(seconds: 20),
      enableNetworkLogging: true,
    );
  }

  /// Staging configuration for pre-release validation.
  factory EnvironmentConfig.staging() {
    return const EnvironmentConfig(
      flavor: AppFlavor.staging,
      appName: 'ShadiDriver Staging',
      apiBaseUrl: 'https://staging-api.shadidriver.in',
      wsBaseUrl: 'wss://staging-api.shadidriver.in/ws',
      connectTimeout: Duration(seconds: 15),
      receiveTimeout: Duration(seconds: 15),
      enableNetworkLogging: true,
    );
  }

  /// Production configuration adhering to strict security and telemetry standards.
  factory EnvironmentConfig.production() {
    return const EnvironmentConfig(
      flavor: AppFlavor.production,
      appName: 'ShadiDriver',
      apiBaseUrl: 'https://api.shadidriver.in',
      wsBaseUrl: 'wss://api.shadidriver.in/ws',
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 10),
      enableNetworkLogging: false,
    );
  }
}
