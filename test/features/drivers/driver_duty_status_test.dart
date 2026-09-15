import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';

void main() {
  group('DriverDutyStatus Domain Tests', () {
    test('supports all 4 operational states with correct codes and labels', () {
      expect(DriverDutyStatus.available.code, equals('AVAILABLE'));
      expect(DriverDutyStatus.available.label, equals('Available for Duty'));

      expect(DriverDutyStatus.busy.code, equals('BUSY'));
      expect(DriverDutyStatus.busy.label, equals('On Active Assignment'));

      expect(DriverDutyStatus.offline.code, equals('OFFLINE'));
      expect(DriverDutyStatus.offline.label, equals('Offline'));

      expect(DriverDutyStatus.availableNow.code, equals('AVAILABLE_NOW'));
      expect(DriverDutyStatus.availableNow.label, equals('Urgent / Ready Now'));
    });

    test('fromCode maps case-insensitively and falls back to offline', () {
      expect(
        DriverDutyStatus.fromCode('available'),
        equals(DriverDutyStatus.available),
      );
      expect(DriverDutyStatus.fromCode('BUSY'), equals(DriverDutyStatus.busy));
      expect(
        DriverDutyStatus.fromCode('offline'),
        equals(DriverDutyStatus.offline),
      );
      expect(
        DriverDutyStatus.fromCode('AVAILABLE_NOW'),
        equals(DriverDutyStatus.availableNow),
      );
      expect(
        DriverDutyStatus.fromCode('unknown_xyz'),
        equals(DriverDutyStatus.offline),
      );
    });

    test('canReceiveOffers is true only for available and availableNow', () {
      expect(DriverDutyStatus.available.canReceiveOffers, isTrue);
      expect(DriverDutyStatus.availableNow.canReceiveOffers, isTrue);
      expect(DriverDutyStatus.busy.canReceiveOffers, isFalse);
      expect(DriverDutyStatus.offline.canReceiveOffers, isFalse);
    });
  });
}
