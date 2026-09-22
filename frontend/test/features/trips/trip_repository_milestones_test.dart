import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/trips/data/mock_trip_repository.dart';
import 'package:shadidriver/features/trips/domain/repositories/trip_repository.dart';

void main() {
  late MockBookingRepository bookingStore;
  late MockTripRepository tripRepo;

  setUp(() {
    bookingStore = MockBookingRepository();
    tripRepo = MockTripRepository(bookingRepository: bookingStore);
  });

  group('TripRepository Milestone Unification', () {
    test('contract exposes all four milestone transitions', () {
      expect(tripRepo, isA<TripRepository>());
    });

    test(
      'startRouteToPickup mirrors DRIVER_ARRIVING into the booking store',
      () async {
        // Seed: accepted booking (pre-trip state before en route).
        await bookingStore.acceptBooking(
          bookingId: 'bk_mock_req_1',
          driverId: 'd1',
        );

        await tripRepo.startRouteToPickup('bk_mock_req_1');

        final booking = (await bookingStore.getSubmissionResult(
          'bk_mock_req_1',
        )).dataOrNull!;
        expect(booking.status, BookingStatus.driverArriving);
      },
    );

    test('markMilestoneArrived mirrors ARRIVED', () async {
      await bookingStore.acceptBooking(
        bookingId: 'bk_mock_req_1',
        driverId: 'd1',
      );
      await tripRepo.startRouteToPickup('bk_mock_req_1');
      await tripRepo.markMilestoneArrived('bk_mock_req_1');

      final booking = (await bookingStore.getSubmissionResult(
        'bk_mock_req_1',
      )).dataOrNull!;
      expect(booking.status, BookingStatus.arrived);
    });

    test('startCeremonyTrip mirrors TRIP_STARTED', () async {
      await bookingStore.acceptBooking(
        bookingId: 'bk_mock_req_1',
        driverId: 'd1',
      );
      await tripRepo.markMilestoneArrived('bk_mock_req_1');
      await tripRepo.startCeremonyTrip('bk_mock_req_1', '1234');

      final booking = (await bookingStore.getSubmissionResult(
        'bk_mock_req_1',
      )).dataOrNull!;
      expect(booking.status, BookingStatus.tripStarted);
    });

    test('completeTrip records COMPLETED (terminal — never reverts)', () async {
      await bookingStore.acceptBooking(
        bookingId: 'bk_mock_req_1',
        driverId: 'd1',
      );
      await tripRepo.startRouteToPickup('bk_mock_req_1');
      await tripRepo.markMilestoneArrived('bk_mock_req_1');
      await tripRepo.startCeremonyTrip('bk_mock_req_1', '1234');
      await tripRepo.completeTrip('bk_mock_req_1');

      final booking = (await bookingStore.getSubmissionResult(
        'bk_mock_req_1',
      )).dataOrNull!;
      expect(booking.status, BookingStatus.completed);

      // Terminal: further stage writes cannot resurrect the booking.
      await tripRepo.startRouteToPickup('bk_mock_req_1');
      final after = (await bookingStore.getSubmissionResult(
        'bk_mock_req_1',
      )).dataOrNull!;
      expect(after.status, BookingStatus.completed);
    });

    test('stage writes on unknown bookings are no-ops, not crashes', () async {
      await tripRepo.startRouteToPickup('bk_nonexistent');
      final result = await bookingStore.getSubmissionResult('bk_nonexistent');
      expect(result.dataOrNull, isNull);
    });
  });
}
