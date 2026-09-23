import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_trip_stage.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/completed_assignments_controller.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart'
    as trip;
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_dashboard_controller.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';

import '../../helpers/mock_env.dart';

void main() {
  late MockDriverRepository mockDriverRepo;
  late MockBookingRepository mockBookingRepo;

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
          ...mockModeOverrides(),
        driverRepositoryProvider.overrideWithValue(mockDriverRepo),
        bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
      ],
    );
  }

  group('Dashboard Active Assignment Lifecycle', () {
    setUp(() {
      mockDriverRepo = MockDriverRepository();
      mockBookingRepo = MockBookingRepository();
    });

    test(
      'no active assignment card data before an offer is accepted',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        final controller = container.read(
          driverDashboardControllerProvider.notifier,
        );
        await controller.loadDashboard();

        expect(controller.state.activeAssignment, isNull);
        expect(controller.state.hasActiveAssignment, isFalse);
        // The seeded booking is still an unclaimed offer, not an assignment.
        expect(controller.state.offers, hasLength(1));
      },
    );

    test(
      'accepting an offer surfaces the assignment on the dashboard',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final actionController = container.read(
          driverBookingActionControllerProvider.notifier,
        );
        expect(await actionController.acceptOffer('bk_mock_req_1'), isTrue);

        final controller = container.read(
          driverDashboardControllerProvider.notifier,
        );
        await controller.loadDashboard();

        final active = controller.state.activeAssignment;
        expect(active, isNotNull);
        expect(active!.bookingId, 'bk_mock_req_1');
        expect(active.bookingReference, 'SD-2026-0100');
        expect(active.stage, DriverTripStage.enRouteToPickup);
      },
    );

    test(
      'completed service clears the active assignment and appears in history',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        // Run the full lifecycle: accept → en route → arrived → ceremony → done.
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

        // The booking store now records the service as COMPLETED.
        final activeInStore = await mockBookingRepo.getDriverActiveAssignments(
          driverId: 'd1',
        );
        expect(activeInStore.dataOrNull, isEmpty);
        expect(
          activeInStore.dataOrNull!.every(
            (b) => b.status != BookingStatus.completed,
          ),
          isTrue,
        );

        // Dashboard reload derives no active assignment from the store.
        final controller = container.read(
          driverDashboardControllerProvider.notifier,
        );
        await controller.loadDashboard();
        expect(controller.state.activeAssignment, isNull);
        expect(controller.state.hasActiveAssignment, isFalse);

        // And the concluded service lands in Completed Assignments.
        container.listen(completedAssignmentsControllerProvider, (_, _) {});
        await container
            .read(completedAssignmentsControllerProvider.notifier)
            .loadCompleted();
        final completedState = container.read(
          completedAssignmentsControllerProvider,
        );
        expect(completedState.assignments, hasLength(1));
        expect(
          completedState.assignments.first.bookingReference,
          'SD-2026-0100',
        );
      },
    );

    test('completed service releases duty to AVAILABLE', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await mockDriverRepo.updateDutyStatus(
        driverId: 'd1',
        status: DriverDutyStatus.busy,
      );

      final tripController = container.read(
        trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
      );
      await tripController.completeService();

      final duty = await mockDriverRepo.getDutyStatus('d1');
      expect(duty.dataOrNull, DriverDutyStatus.available);
    });
  });
}
