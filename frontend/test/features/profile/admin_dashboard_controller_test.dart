import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_trip_stage.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart'
    as trip;
import 'package:shadidriver/features/home/data/mock_repositories.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';
import 'package:shadidriver/features/profile/presentation/controllers/admin_dashboard_controller.dart';

void main() {
  late MockDriverRepository mockDriverRepo;
  late MockBookingRepository mockBookingRepo;
  late ProviderContainer container;

  setUp(() {
    mockDriverRepo = MockDriverRepository();
    mockBookingRepo = MockBookingRepository();
    container = ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(mockDriverRepo),
        bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
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
      expect(state.dispatchEntries.first.chauffeurDisplayName, 'Rajesh Kumar');
      expect(
        state.dispatchEntries.first.statusLabel,
        'AWAITING ACCEPTANCE',
      );

      // On-Duty KPI counts every roster chauffeur not OFFLINE (d1-d3, d5 = 4).
      expect(state.onDutyCount, 4);

      // A REQUESTED booking is not yet a live ceremony.
      expect(state.liveCeremoniesCount, 0);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('live ceremony KPI increments when a trip starts', () async {
      container.listen(adminDashboardControllerProvider, (_, _) {});

      // Driver accepts, then starts the journey — booking leaves REQUESTED.
      final actionController = container.read(
        driverBookingActionControllerProvider.notifier,
      );
      await actionController.acceptOffer('bk_mock_req_1');

      final tripController = container.read(
        trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
      );
      await tripController.startEnRoute();

      // Give the fire-and-forget duty engagement a moment to land.
      await Future<void>.delayed(const Duration(milliseconds: 250));

      await container
          .read(adminDashboardControllerProvider.notifier)
          .loadDashboard();

      final state = container.read(adminDashboardControllerProvider);

      expect(state.liveCeremoniesCount, 1);
      expect(
        state.dispatchEntries.first.statusLabel,
        'EN ROUTE',
      );
      // Chauffeur went BUSY on trip start — still counts as on-duty.
      expect(state.onDutyCount, 4);
    });

    test('completed service drops out of the dispatch monitor', () async {
      container.listen(adminDashboardControllerProvider, (_, _) {});

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

      // COMPLETED is terminal: no rows, no live ceremonies.
      expect(state.dispatchEntries, isEmpty);
      expect(state.liveCeremoniesCount, 0);
    });

    test('busying a chauffeur does not reduce on-duty KPI below offline count',
        () async {
      container.listen(adminDashboardControllerProvider, (_, _) {});

      // d1 goes BUSY (mid-assignment), d2 stays AVAILABLE.
      await mockDriverRepo.updateDutyStatus(
        driverId: 'd1',
        status: DriverDutyStatus.busy,
      );

      await container
          .read(adminDashboardControllerProvider.notifier)
          .loadDashboard();

      final state = container.read(adminDashboardControllerProvider);

      // BUSY still counts as on-duty: d1(busy) + d2 + d3 + d5 = 4.
      expect(state.onDutyCount, 4);
    });

    test('DriverTripStage completed maps finished trips for history views', () {
      expect(DriverTripStage.completed.isFinished, isTrue);
    });
  });
}
