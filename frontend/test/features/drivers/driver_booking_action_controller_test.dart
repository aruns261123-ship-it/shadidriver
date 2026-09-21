import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_decline_reason.dart';
import 'package:shadidriver/features/drivers/presentation/controllers/driver_booking_action_controller.dart';

void main() {
  late MockBookingRepository mockBookingRepo;
  const driver1 = 'd1';
  const driver2 = 'd2';
  const validBookingId = 'bk_mock_req_1';

  setUp(() {
    mockBookingRepo = MockBookingRepository();
  });

  group('DriverBookingActionController Tests', () {
    test(
      'acceptOffer succeeds and transitions booking to driverAccepted',
      () async {
        final controller = DriverBookingActionController(
          bookingRepository: mockBookingRepo,
          driverId: driver1,
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
        final controller1 = DriverBookingActionController(
          bookingRepository: mockBookingRepo,
          driverId: driver1,
        );
        final controller2 = DriverBookingActionController(
          bookingRepository: mockBookingRepo,
          driverId: driver2,
        );

        // Driver 1 accepts
        final success1 = await controller1.acceptOffer(validBookingId);
        expect(success1, isTrue);

        // Driver 2 attempts to accept the same booking
        final success2 = await controller2.acceptOffer(validBookingId);
        expect(success2, isFalse);
        expect(controller2.state.isAccepted, isFalse);
        expect(controller2.state.isConflict, isTrue);
        expect(
          controller2.state.errorMessage,
          contains('already been accepted by another chauffeur'),
        );
      },
    );

    test(
      'declineOffer succeeds with mandatory reason and marks offer declined',
      () async {
        final controller = DriverBookingActionController(
          bookingRepository: mockBookingRepo,
          driverId: driver1,
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
  });
}
