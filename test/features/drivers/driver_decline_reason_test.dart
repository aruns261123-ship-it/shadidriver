import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_decline_reason.dart';

void main() {
  group('DriverDeclineReason Domain Tests', () {
    test('supports all required operational decline reasons', () {
      expect(
        DriverDeclineReason.timingConflict.code,
        equals('TIMING_CONFLICT'),
      );
      expect(
        DriverDeclineReason.timingConflict.label,
        equals('Timing / Schedule Conflict'),
      );

      expect(DriverDeclineReason.locationIssue.code, equals('LOCATION_ISSUE'));
      expect(
        DriverDeclineReason.locationIssue.label,
        equals('Pickup / Venue Location Too Far'),
      );

      expect(DriverDeclineReason.vehicleIssue.code, equals('VEHICLE_ISSUE'));
      expect(
        DriverDeclineReason.vehicleIssue.label,
        equals('Vehicle Maintenance / Unsuitable'),
      );

      expect(
        DriverDeclineReason.personalEmergency.code,
        equals('PERSONAL_EMERGENCY'),
      );
      expect(
        DriverDeclineReason.personalEmergency.label,
        equals('Personal / Family Emergency'),
      );

      expect(
        DriverDeclineReason.alreadyCommitted.code,
        equals('ALREADY_COMMITTED'),
      );
      expect(
        DriverDeclineReason.alreadyCommitted.label,
        equals('Already Committed to Another Ceremony'),
      );

      expect(DriverDeclineReason.other.code, equals('OTHER'));
      expect(
        DriverDeclineReason.other.label,
        equals('Other (Specification Required)'),
      );
    });

    test('fromCode maps correctly and handles null/unknown gracefully', () {
      expect(DriverDeclineReason.fromCode(null), isNull);
      expect(
        DriverDeclineReason.fromCode('timing_conflict'),
        equals(DriverDeclineReason.timingConflict),
      );
      expect(
        DriverDeclineReason.fromCode('VEHICLE_ISSUE'),
        equals(DriverDeclineReason.vehicleIssue),
      );
      expect(
        DriverDeclineReason.fromCode('UNKNOWN_CODE'),
        equals(DriverDeclineReason.other),
      );
    });
  });
}
