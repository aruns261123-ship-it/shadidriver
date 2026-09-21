import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_pricing_policy.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_dashboard_controller.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

void main() {
  late MockDriverRepository mockDriverRepo;
  late MockBookingRepository mockBookingRepo;
  late DevelopmentBookingPricingPolicy pricingPolicy;
  const testDriverId = 'd1';

  setUp(() {
    mockDriverRepo = MockDriverRepository();
    pricingPolicy = const DevelopmentBookingPricingPolicy();
    mockBookingRepo = MockBookingRepository();
  });

  group('DriverDashboardController Tests', () {
    test('initializes and loads available status and offers', () async {
      final controller = DriverDashboardController(
        driverRepository: mockDriverRepo,
        bookingRepository: mockBookingRepo,
        pricingPolicy: pricingPolicy,
        driverId: testDriverId,
      );

      await controller.loadDashboard();

      expect(controller.state.dutyStatus, DriverDutyStatus.available);
      expect(controller.state.canReceiveOffers, isTrue);
      expect(controller.state.offers.isNotEmpty, isTrue);
      expect(controller.state.offers.first.bookingReference, 'SD-2026-0100');
    });

    test(
      'setting duty status to OFFLINE clears offers and pauses dispatch',
      () async {
        final controller = DriverDashboardController(
          driverRepository: mockDriverRepo,
          bookingRepository: mockBookingRepo,
          pricingPolicy: pricingPolicy,
          driverId: testDriverId,
        );
        await controller.loadDashboard();

        final success = await controller.setDutyStatus(
          DriverDutyStatus.offline,
        );

        expect(success, isTrue);
        expect(controller.state.dutyStatus, DriverDutyStatus.offline);
        expect(controller.state.canReceiveOffers, isFalse);
        expect(controller.state.offers.isEmpty, isTrue);
      },
    );

    test(
      'setting duty status back to AVAILABLE restores incoming offers',
      () async {
        final controller = DriverDashboardController(
          driverRepository: mockDriverRepo,
          bookingRepository: mockBookingRepo,
          pricingPolicy: pricingPolicy,
          driverId: testDriverId,
        );
        await controller.loadDashboard();

        await controller.setDutyStatus(DriverDutyStatus.offline);
        expect(controller.state.offers.isEmpty, isTrue);

        await controller.setDutyStatus(DriverDutyStatus.available);
        expect(controller.state.dutyStatus, DriverDutyStatus.available);
        expect(controller.state.offers.isNotEmpty, isTrue);
      },
    );

    test('refreshOffers updates offer list when driver is available', () async {
      final controller = DriverDashboardController(
        driverRepository: mockDriverRepo,
        bookingRepository: mockBookingRepo,
        pricingPolicy: pricingPolicy,
        driverId: testDriverId,
      );
      await controller.loadDashboard();

      await controller.refreshOffers();

      expect(controller.state.offers, isNotEmpty);
      expect(controller.state.errorMessage, isNull);
    });
  });
}
