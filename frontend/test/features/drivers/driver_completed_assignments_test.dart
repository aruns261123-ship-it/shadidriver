import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/completed_assignments_controller.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_active_trip_controller.dart'
    as trip;
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_dashboard_controller.dart'
    show currentDriverIdProvider, driverDutyStatusProvider;

void main() {
  late MockDriverRepository mockDriverRepo;
  late MockBookingRepository mockBookingRepo;
  const testDriverId = 'd1';

  setUp(() {
    mockDriverRepo = MockDriverRepository();
    mockBookingRepo = MockBookingRepository();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        driverRepositoryProvider.overrideWithValue(mockDriverRepo),
        bookingRepositoryProvider.overrideWithValue(mockBookingRepo),
        currentDriverIdProvider.overrideWithValue(testDriverId),
      ],
    );
  }

  group('CompletedAssignmentsController Tests', () {
    test('starts empty when chauffeur has no completed history', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      final controller = CompletedAssignmentsController(
        bookingRepository: mockBookingRepo,
        driverId: testDriverId,
      );
      await controller.loadCompleted();

      expect(controller.state.assignments, isEmpty);
      expect(controller.state.errorMessage, isNull);
    });

    test(
      'lists booking as completed assignment after completeService',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        final controller = CompletedAssignmentsController(
          bookingRepository: mockBookingRepo,
          driverId: testDriverId,
        );

        // Seed a completed booking (simulates trip console conclusion).
        mockBookingRepo.markBookingCompleted('bk_mock_req_1');

        await controller.loadCompleted();

        expect(controller.state.assignments, hasLength(1));
        final trip = controller.state.assignments.first;
        expect(trip.bookingId, 'bk_mock_req_1');
        expect(trip.bookingReference, 'SD-2026-0100');
        expect(trip.stage.isFinished, isTrue);
        expect(trip.tripCompletedAt, isNull); // completion time is live-only
      },
    );
  });

  group('DriverActiveTripController completion wiring', () {
    test(
      'startEnRoute engages profile duty to BUSY (On Active Assignment)',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        final tripController = container.read(
          trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
        );
        await tripController.startEnRoute();

        final duty = await mockDriverRepo.getDutyStatus(testDriverId);
        expect(duty.dataOrNull, DriverDutyStatus.busy);
      },
    );

    test(
      'completeService records booking as COMPLETED and releases duty to AVAILABLE',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        // Set duty to BUSY first (as it would be mid-assignment).
        await mockDriverRepo.updateDutyStatus(
          driverId: testDriverId,
          status: DriverDutyStatus.busy,
        );

        final tripController = container.read(
          trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
        );
        await tripController.completeService();

        // Booking store now holds the completed record.
        final completed = await mockBookingRepo.getCompletedBookings(
          driverId: testDriverId,
        );
        expect(completed.dataOrNull, hasLength(1));
        expect(completed.dataOrNull?.first.status, BookingStatus.completed);

        // Duty status released back to AVAILABLE.
        final duty = await mockDriverRepo.getDutyStatus(testDriverId);
        expect(duty.dataOrNull, DriverDutyStatus.available);
      },
    );
  });

  group('End-to-end dashboard flow', () {
    test(
      'completed booking appears in completed assignments via providers',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        // Simulate the full trip lifecycle through the trip controller.
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

        // Keep the autoDispose provider alive while we await its load.
        container.listen(completedAssignmentsControllerProvider, (_, _) {});
        await container
            .read(completedAssignmentsControllerProvider.notifier)
            .loadCompleted();

        final completedState = container.read(
          completedAssignmentsControllerProvider,
        );

        // The console history now shows the concluded service.
        expect(completedState.assignments, hasLength(1));
        expect(
          completedState.assignments.first.bookingReference,
          'SD-2026-0100',
        );

        // Dashboard duty status reflects release.
        final dashboardDuty = await container.read(
          driverDutyStatusProvider('d1').future,
        );
        expect(dashboardDuty, DriverDutyStatus.available);
      },
    );

    test(
      'duty lifecycle: accept offer engages BUSY, completion releases AVAILABLE',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        // Accepting an offer engages the chauffeur BUSY via the action
        // controller, mirroring the real accept-offer screen flow.
        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final actionController = container.read(
          driverBookingActionControllerProvider.notifier,
        );
        final accepted = await actionController.acceptOffer('bk_mock_req_1');
        expect(accepted, isTrue);

        // Allow the fire-and-forget duty engagement to land in the store.
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final busyAfterAccept = await mockDriverRepo.getDutyStatus(
          testDriverId,
        );
        expect(busyAfterAccept.dataOrNull, DriverDutyStatus.busy);

        // Completing the assignment releases duty back to AVAILABLE.
        final tripController = container.read(
          trip.driverActiveTripControllerProvider('bk_mock_req_1').notifier,
        );
        await tripController.completeService();

        final dutyAfterComplete = await mockDriverRepo.getDutyStatus(
          testDriverId,
        );
        expect(dutyAfterComplete.dataOrNull, DriverDutyStatus.available);
      },
    );
  });
}
