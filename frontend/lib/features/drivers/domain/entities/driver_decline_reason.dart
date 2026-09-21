/// Supported decline reasons for chauffeurs rejecting an incoming booking request.
///
/// In accordance with Milestone 5 requirements, a valid reason is strictly mandatory
/// prior to registering a decline action.
enum DriverDeclineReason {
  timingConflict('TIMING_CONFLICT', 'Timing / Schedule Conflict'),
  locationIssue('LOCATION_ISSUE', 'Pickup / Venue Location Too Far'),
  vehicleIssue('VEHICLE_ISSUE', 'Vehicle Maintenance / Unsuitable'),
  personalEmergency('PERSONAL_EMERGENCY', 'Personal / Family Emergency'),
  alreadyCommitted(
    'ALREADY_COMMITTED',
    'Already Committed to Another Ceremony',
  ),
  other('OTHER', 'Other (Specification Required)');

  final String code;
  final String label;

  String get displayLabel => label;

  const DriverDeclineReason(this.code, this.label);

  static DriverDeclineReason? fromCode(String? code) {
    if (code == null) return null;
    return DriverDeclineReason.values.firstWhere(
      (r) => r.code.toUpperCase() == code.toUpperCase(),
      orElse: () => DriverDeclineReason.other,
    );
  }
}
