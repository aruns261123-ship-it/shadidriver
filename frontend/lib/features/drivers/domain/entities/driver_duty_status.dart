/// Operational duty states for chauffeurs.
///
/// In accordance with ShadiDriver dispatch and availability specifications:
/// - [available]: Chauffeur is on-duty and accepting ceremonial reservation requests.
/// - [busy]: Chauffeur is actively engaged in an accepted or en-route assignment.
/// - [offline]: Chauffeur is off-duty; no booking offers will be dispatched.
/// - [availableNow]: Chauffeur is marked for urgent / instant wedding emergency dispatch.
enum DriverDutyStatus {
  available('AVAILABLE', 'Available for Duty'),
  busy('BUSY', 'On Active Assignment'),
  offline('OFFLINE', 'Offline'),
  availableNow('AVAILABLE_NOW', 'Urgent / Ready Now');

  final String code;
  final String label;

  String get displayLabel => label;

  const DriverDutyStatus(this.code, this.label);

  /// Resolves enum from wire/database string.
  static DriverDutyStatus fromCode(String code) {
    return DriverDutyStatus.values.firstWhere(
      (s) => s.code.toUpperCase() == code.toUpperCase(),
      orElse: () => DriverDutyStatus.offline,
    );
  }

  /// Whether the driver is currently eligible to receive new ceremonial offers.
  bool get canReceiveOffers =>
      this == DriverDutyStatus.available ||
      this == DriverDutyStatus.availableNow;
}
