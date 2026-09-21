import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/drivers/domain/entities/driver_decline_reason.dart';

void main() {
  group('MockBookingRepository Driver Operations & Concurrency Tests', () {
    late MockBookingRepository repository;

    setUp(() {
      repository = MockBookingRepository();
    });

    test(
      'getDriverBookingRequests lists available REQUESTED bookings',
      () async {
        final res = await repository.getDriverBookingRequests(driverId: 'd1');
        expect(res.isSuccess, isTrue);
        final requests = res.dataOrNull!;
        expect(requests.isNotEmpty, isTrue);

        // Verify all returned requests are in requested status
        for (final req in requests) {
          expect(req.status, equals(BookingStatus.requested));
        }
      },
    );

    test(
      'getDriverBookingDetails returns details for valid bookingId',
      () async {
        final res = await repository.getDriverBookingDetails(
          bookingId: 'bk_mock_req_1',
          driverId: 'd1',
        );
        expect(res.isSuccess, isTrue);
        expect(res.dataOrNull?.bookingReference, equals('SD-2026-0100'));
        expect(res.dataOrNull?.ceremonyType, equals('Baraat'));
      },
    );

    test(
      'getDriverBookingDetails returns NotFoundFailure for invalid ID',
      () async {
        final res = await repository.getDriverBookingDetails(
          bookingId: 'invalid_id_999',
          driverId: 'd1',
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<NotFoundFailure>());
      },
    );

    test(
      'acceptBooking updates status to driverAccepted and assigns chauffeur',
      () async {
        final acceptRes = await repository.acceptBooking(
          bookingId: 'bk_mock_req_1',
          driverId: 'd1',
        );

        expect(acceptRes.isSuccess, isTrue);
        final accepted = acceptRes.dataOrNull!;
        expect(accepted.status, equals(BookingStatus.driverAccepted));
        expect(accepted.chauffeurId, equals('d1'));

        // Verify synchronized booking summary seen by customer
        final summaryRes = await repository.getBookingById('bk_mock_req_1');
        expect(summaryRes.isSuccess, isTrue);
        expect(summaryRes.dataOrNull?.status, equals('DRIVER_ACCEPTED'));
      },
    );

    test(
      'CONCURRENCY RULE: Prevents duplicate acceptance; second driver receives ConflictFailure',
      () async {
        // Driver 1 accepts booking
        final firstAcceptRes = await repository.acceptBooking(
          bookingId: 'bk_mock_req_1',
          driverId: 'd1',
        );
        expect(firstAcceptRes.isSuccess, isTrue);
        expect(
          firstAcceptRes.dataOrNull?.status,
          equals(BookingStatus.driverAccepted),
        );

        // Driver 2 attempts to accept the SAME booking concurrently
        final secondAcceptRes = await repository.acceptBooking(
          bookingId: 'bk_mock_req_1',
          driverId: 'd2',
        );

        // Must fail deterministically with ConflictFailure
        expect(secondAcceptRes.isFailure, isTrue);
        expect(secondAcceptRes.failureOrNull, isA<ConflictFailure>());
        expect(
          secondAcceptRes.failureOrNull?.message,
          contains('no longer available'),
        );
      },
    );

    test('declineBooking removes request from declining driver list', () async {
      // Initially visible
      final initialRequests = await repository.getDriverBookingRequests(
        driverId: 'd1',
      );
      expect(
        initialRequests.dataOrNull?.any((r) => r.bookingId == 'bk_mock_req_1'),
        isTrue,
      );

      // Driver 1 declines with mandatory reason
      final declineRes = await repository.declineBooking(
        bookingId: 'bk_mock_req_1',
        driverId: 'd1',
        reason: DriverDeclineReason.timingConflict,
      );
      expect(declineRes.isSuccess, isTrue);

      // Subsequent fetch for Driver 1 should no longer contain this booking
      final postDeclineRequests = await repository.getDriverBookingRequests(
        driverId: 'd1',
      );
      expect(
        postDeclineRequests.dataOrNull?.any(
          (r) => r.bookingId == 'bk_mock_req_1',
        ),
        isFalse,
      );

      // But Driver 2 should still see it
      final driver2Requests = await repository.getDriverBookingRequests(
        driverId: 'd2',
      );
      expect(
        driver2Requests.dataOrNull?.any((r) => r.bookingId == 'bk_mock_req_1'),
        isTrue,
      );
    });
  });
}
