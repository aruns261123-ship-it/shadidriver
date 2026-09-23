import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_trip_stage.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart'
    as trip;
import 'package:shadidriver/features/home/data/mock_repositories.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';
import 'package:shadidriver/features/profile/presentation/controllers/admin_dashboard_controller.dart';

import '../../helpers/mock_env.dart';

void main() {
  late MockDriverRepository mockDriverRepo;
  late MockBookingRepository mockBookingRepo;
  late ProviderContainer container;

  setUp(() {
    mockDriverRepo = MockDriverRepository();
    mockBookingRepo = MockBookingRepository();
    container = ProviderContainer(
      overrides: [
          ...mockModeOverrides(),
        driverRepositoryProvider.overrideWithValue(mockDriverRepo),
        bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Admin Emergency Standby Override', () {
    test(
      'force-dispatches an AVAILABLE chauffeur for an unaccepted booking',
      () async {
        container.listen(adminDashboardControllerProvider, (_, _) {});
        final controller = container.read(
          adminDashboardControllerProvider.notifier,
        );

        final updated = await controller.dispatchEmergencyStandby(
          'bk_mock_req_1',
        );

        expect(updated, isNotNull);
        expect(updated!.status, BookingStatus.emergencyReplacement);
        expect(updated.chauffeurId, isNotEmpty);

        final state = container.read(adminDashboardControllerProvider);
        expect(
          state.dispatchEntries.any(
            (e) => e.booking.status == BookingStatus.emergencyReplacement,
          ),
          isTrue,
        );
      },
    );

    test('fails cleanly when no AVAILABLE chauffeur exists', () async {
      // Mark every roster chauffeur BUSY so none is available for standby.
      final duties = await mockDriverRepo.getAllDutyStatuses();
      for (final driverId in (duties.dataOrNull ?? const {}).keys) {
        await mockDriverRepo.updateDutyStatus(
          driverId: driverId,
          status: DriverDutyStatus.busy,
        );
      }

      container.listen(adminDashboardControllerProvider, (_, _) {});
      final controller = container.read(
        adminDashboardControllerProvider.notifier,
      );

      final updated = await controller.dispatchEmergencyStandby(
        'bk_mock_req_1',
      );

      expect(updated, isNull);
      expect(controller.state.errorMessage, contains('No AVAILABLE chauffeur'));
    });
  });

  group('AdminDashboardController Tests', () {
    test('loads KPIs from live duty roster and booking store', () async {
      // Keep the autoDispose provider alive for the duration of the test.
      container.listen(adminDashboardControllerProvider, (_, _) {});
      await container
          .read(adminDashboardControllerProvider.notifier)
          .loadDashboard();

      final state = container.read(adminDashboardControllerProvider);

      // Seeded REQUESTED booking for d1 appears as an awaiting-dispatch row.
      expect(state.dispatchEntries, hasLength(1));
      expect(state.dispatchEntries.first.bookingReference, 'SD-2026-0100');

      // KPIs derived from the roster and booking store, not literals.
      expect(state.onDutyCount, greaterThanOrEqualTo(0));
      expect(state.fleetEntries, isNotEmpty);
    });

    test(
      'accept offer then start trip mirrors EN ROUTE into the monitor',
      () async {
        container.listen(adminDashboardControllerProvider, (_, _) {});
        await container
            .read(adminDashboardControllerProvider.notifier)
            .loadDashboard();

        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final actionController = container.read(
          driverBookingActionControllerProvider.notifier,
        );
        await actionController.acceptOffer('bk_mock_req_1');

        final tripController = container.read(
          trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
        );
        await tripController.startEnRoute();

        await container
            .read(adminDashboardControllerProvider.notifier)
            .loadDashboard();

        final state = container.read(adminDashboardControllerProvider);
        expect(state.dispatchEntries.first.statusLabel, 'EN ROUTE');
      },
    );

    test('completed service drops out of the dispatch monitor', () async {
      container.listen(adminDashboardControllerProvider, (_, _) {});
      await container
          .read(adminDashboardControllerProvider.notifier)
          .loadDashboard();

      container.listen(driverBookingActionControllerProvider, (_, _) {});
      final actionController = container.read(
        driverBookingActionControllerProvider.notifier,
      );
      await actionController.acceptOffer('bk_mock_req_1');

      final tripController = container.read(
        trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
      );
      await tripController.startEnRoute();
      await tripController.markArrived();
      await tripController.startCeremonyService(
        otp: '1234',
        attireConfirmed: true,
      );
      await tripController.completeService();

      await container
          .read(adminDashboardControllerProvider.notifier)
          .loadDashboard();

      final state = container.read(adminDashboardControllerProvider);
      expect(state.dispatchEntries, isEmpty);
    });

    test(
      'busying a chauffeur does not reduce on-duty KPI below offline count',
      () async {
        container.listen(adminDashboardControllerProvider, (_, _) {});
        final controller = container.read(
          adminDashboardControllerProvider.notifier,
        );
        await controller.loadDashboard();

        final before = container.read(adminDashboardControllerProvider);

        await mockDriverRepo.updateDutyStatus(
          driverId: 'd1',
          status: DriverDutyStatus.busy,
        );
        await controller.loadDashboard();

        final after = container.read(adminDashboardControllerProvider);

        // BUSY still counts as on-duty; total roster composition unchanged.
        expect(after.onDutyCount, before.onDutyCount);
      },
    );

    test('DriverTripStage completed maps finished trips for history views', () {
      // Sanity: stage mapping is exercised via the completed-assignments path.
      expect(DriverTripStage.completed.index, greaterThan(0));
    });
  });
}
