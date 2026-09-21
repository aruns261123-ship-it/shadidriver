/// Environment flavor for ShadiDriver.
enum AppFlavor {
  development,
  staging,
  production;

  bool get isDev => this == AppFlavor.development;
  bool get isStaging => this == AppFlavor.staging;
  bool get isProd => this == AppFlavor.production;
}
