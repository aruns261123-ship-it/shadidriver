import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';

void main() {
  group('MockBookingRepository Submission & Idempotency Tests', () {
    late MockBookingRepository repository;
    late BookingDraft validDraft;

    setUp(() {
      repository = MockBookingRepository();
      validDraft =
          BookingDraft.initial(
            vehicleId: 'v1',
            vehicleName: 'BMW 5 Series',
            vehicleClass: 'Luxury Sedan',
            chauffeurId: 'd1',
            basePricePaise: 2500000,
            estimatedTotalPaise: 2500000,
            advanceTokenPaise: 500000,
          ).copyWith(
            pickupAddress: 'The Oberoi Hotel, New Delhi',
            destinationAddress: 'Grand Imperial Banquets, MG Road',
            primaryContactName: 'Vikram Malhotra',
            primaryContactPhone: '9810012345',
          );
    });

    test('valid request submits successfully in requested status', () async {
      final request = BookingSubmissionRequest.fromDraft(
        validDraft,
        idempotencyKey: 'key_valid_1',
      );

      final result = await repository.submitBooking(request);

      expect(result.isSuccess, isTrue);
      final submission = result.dataOrNull!;
      expect(submission.bookingId, startsWith('bk_v1_'));
      expect(submission.bookingReference, startsWith('SD-2026-'));
      expect(submission.status, equals(BookingStatus.requested));
      expect(submission.isIdempotentReplay, isFalse);
      expect(submission.estimatedTotalPaise, equals(2500000));
      expect(submission.advanceTokenPaise, equals(500000));
      expect(submission.nextStepMessage, contains('received'));
    });

    test(
      'submitting with identical idempotency key returns cached replay result',
      () async {
        final request1 = BookingSubmissionRequest.fromDraft(
          validDraft,
          idempotencyKey: 'idem_replay_test',
        );

        final firstResult = await repository.submitBooking(request1);
        expect(firstResult.isSuccess, isTrue);
        final initialSubmission = firstResult.dataOrNull!;
        expect(initialSubmission.isIdempotentReplay, isFalse);

        // Submit second time with identical idempotency key
        final request2 = BookingSubmissionRequest.fromDraft(
          validDraft,
          idempotencyKey: 'idem_replay_test',
        );

        final secondResult = await repository.submitBooking(request2);
        expect(secondResult.isSuccess, isTrue);
        final replayedSubmission = secondResult.dataOrNull!;

        // Must return identical booking ID and reference
        expect(
          replayedSubmission.bookingId,
          equals(initialSubmission.bookingId),
        );
        expect(
          replayedSubmission.bookingReference,
          equals(initialSubmission.bookingReference),
        );
        expect(replayedSubmission.isIdempotentReplay, isTrue);
      },
    );

    test('incomplete request returns validation failure', () async {
      final incompleteDraft = validDraft.copyWith(primaryContactPhone: '');
      final request = BookingSubmissionRequest.fromDraft(
        incompleteDraft,
        idempotencyKey: 'key_invalid',
      );

      final result = await repository.submitBooking(request);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('Incomplete'));
    });

    test(
      'getSubmissionResult retrieves stored submission by bookingId',
      () async {
        final request = BookingSubmissionRequest.fromDraft(
          validDraft,
          idempotencyKey: 'key_lookup_test',
        );

        final submitRes = await repository.submitBooking(request);
        final bookingId = submitRes.dataOrNull!.bookingId;

        final fetchRes = await repository.getSubmissionResult(bookingId);
        expect(fetchRes.isSuccess, isTrue);
        expect(fetchRes.dataOrNull?.bookingId, equals(bookingId));
        expect(
          fetchRes.dataOrNull?.bookingReference,
          equals(submitRes.dataOrNull!.bookingReference),
        );
      },
    );
  });
}
