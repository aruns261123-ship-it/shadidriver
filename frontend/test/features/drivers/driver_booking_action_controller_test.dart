import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/app/providers/app_providers.dart';
import 'package:shadidriver/features/home/data/mock_repositories.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_decline_reason.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_duty_status.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';

import '../../helpers/mock_env.dart';

void main() {
  late MockBookingRepository mockBookingRepo;
  late MockDriverRepository mockDriverRepo;
  late ProviderContainer container;
  const driver1 = 'd1';
  const driver2 = 'd2';
  const validBookingId = 'bk_mock_req_1';

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

  group('DriverBookingActionController Tests', () {
    test(
      'acceptOffer succeeds and transitions booking to driverAccepted',
      () async {
        // Keep the autoDispose provider alive for the duration of the test.
        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final controller = container.read(
          driverBookingActionControllerProvider.notifier,
        );

        final success = await controller.acceptOffer(validBookingId);

        expect(success, isTrue);
        expect(controller.state.isAccepted, isTrue);
        expect(controller.state.isConflict, isFalse);
        expect(
          controller.state.acceptedResult?.status,
          BookingStatus.driverAccepted,
        );
        expect(controller.state.acceptedResult?.chauffeurId, driver1);
      },
    );

    test(
      'CONCURRENCY LOCK: Second driver attempting to accept receives conflict failure',
      () async {
        // Keep the autoDispose provider alive for the duration of the test,
        // then simulate driver 1's acceptance through the controller.
        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final controller1 = container.read(
          driverBookingActionControllerProvider.notifier,
        );
        final success1 = await controller1.acceptOffer(validBookingId);
        expect(success1, isTrue);

        // Driver 2 attempts to accept the same booking via a fresh repository
        // view: the mock repo enforces the single-acceptance lock.
        final result2 = await mockBookingRepo.acceptBooking(
          bookingId: validBookingId,
          driverId: driver2,
        );
        expect(result2.isFailure, isTrue);
        expect(
          result2.fold((f) => f.message, (_) => ''),
          contains('already been accepted by another chauffeur'),
        );
      },
    );

    test(
      'declineOffer succeeds with mandatory reason and marks offer declined',
      () async {
        // Keep the autoDispose provider alive for the duration of the test.
        container.listen(driverBookingActionControllerProvider, (_, _) {});
        final controller = container.read(
          driverBookingActionControllerProvider.notifier,
        );

        final success = await controller.declineOffer(
          validBookingId,
          DriverDeclineReason.timingConflict,
        );

        expect(success, isTrue);
        expect(controller.state.isDeclined, isTrue);
        expect(controller.state.errorMessage, isNull);

        // Declined offer no longer visible for driver 1
        final requestsResult = await mockBookingRepo.getDriverBookingRequests(
          driverId: driver1,
        );
        final requests = requestsResult.fold((l) => [], (r) => r);
        expect(requests.any((req) => req.bookingId == validBookingId), isFalse);
      },
    );

    test('acceptOffer engages profile duty status to BUSY', () async {
      // Keep the autoDispose provider alive for the duration of the test.
      container.listen(driverBookingActionControllerProvider, (_, _) {});
      final controller = container.read(
        driverBookingActionControllerProvider.notifier,
      );

      final success = await controller.acceptOffer(validBookingId);
      expect(success, isTrue);

      final duty = await mockDriverRepo.getDutyStatus(driver1);
      expect(duty.dataOrNull, DriverDutyStatus.busy);
    });
  });
}
