import 'package:flutter_test/flutter_test.dart';
import 'package:shadidriver/core/errors/failures.dart';
import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/bookings/data/mock_booking_repository.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_draft.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_status.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_request.dart';
import 'package:shadidriver/features/bookings/domain/entities/booking_submission_result.dart';
import 'package:shadidriver/features/bookings/presentation/controllers/booking_review_controller.dart';

class FailingBookingRepository extends MockBookingRepository {
  bool shouldFailSubmission = false;

  @override
  Future<Result<BookingSubmissionResult>> submitBooking(
    BookingSubmissionRequest request,
  ) async {
    if (shouldFailSubmission) {
      await Future.delayed(const Duration(milliseconds: 50));
      return Result.failure(
        const NetworkFailure('Network connection timeout. Please try again.'),
      );
    }
    return super.submitBooking(request);
  }
}

void main() {
  group('BookingReviewController Tests', () {
    late FailingBookingRepository repository;
    late BookingDraft testDraft;

    setUp(() async {
      repository = FailingBookingRepository();
      testDraft = BookingDraft.initial(
        vehicleId: 'v1',
        vehicleName: 'BMW 5 Series',
        vehicleClass: 'Luxury Sedan',
        chauffeurId: 'd1',
        basePricePaise: 2500000,
        estimatedTotalPaise: 2500000,
        advanceTokenPaise: 500000,
      ).copyWith(
        pickupAddress: 'The Oberoi Hotel, New Delhi',
        destinationAddress: 'Grand Imperial Banquets',
        primaryContactName: 'Vikram Malhotra',
        primaryContactPhone: '9810012345',
      );

      // Save draft to repository so controller can load it
      await repository.createBookingDraft(testDraft);
    });

    test('initial state loads draft and generates idempotency key', () async {
      final controller = BookingReviewController(
        bookingRepository: repository,
        draftId: testDraft.id,
      );

      // Await async _loadDraft
      await Future.delayed(const Duration(milliseconds: 150));

      expect(controller.state.isLoadingDraft, isFalse);
      expect(controller.state.draft, isNotNull);
      expect(controller.state.draft?.id, equals(testDraft.id));
      expect(controller.state.idempotencyKey, isNotEmpty);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.submissionResult, isNull);
    });

    test('submitBooking successfully submits valid draft', () async {
      final controller = BookingReviewController(
        bookingRepository: repository,
        draftId: testDraft.id,
      );
      await Future.delayed(const Duration(milliseconds: 150));

      final success = await controller.submitBooking();

      expect(success, isTrue);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.submissionResult, isNotNull);
      expect(
        controller.state.submissionResult?.status,
        equals(BookingStatus.requested),
      );
      expect(
        controller.state.submissionResult?.bookingReference,
        startsWith('SD-2026-'),
      );
    });

    test('submitBooking blocks incomplete drafts', () async {
      final incompleteDraft = testDraft.copyWith(pickupAddress: '');
      await repository.saveBookingDraft(incompleteDraft);

      final controller = BookingReviewController(
        bookingRepository: repository,
        draftId: incompleteDraft.id,
      );
      await Future.delayed(const Duration(milliseconds: 150));

      final success = await controller.submitBooking();

      expect(success, isFalse);
      expect(controller.state.isSuccess, isFalse);
      expect(controller.state.errorMessage, contains('incomplete'));
    });

    test('double-tap protection blocks concurrent submissions', () async {
      final controller = BookingReviewController(
        bookingRepository: repository,
        draftId: testDraft.id,
      );
      await Future.delayed(const Duration(milliseconds: 150));

      // Trigger first submission (takes 250ms in mock)
      final firstCall = controller.submitBooking();

      // State is now submitting
      expect(controller.state.isSubmitting, isTrue);

      // Trigger second simultaneous submission (double tap)
      final secondCall = controller.submitBooking();

      // Second call must return false immediately
      final secondResult = await secondCall;
      expect(secondResult, isFalse);

      // First call completes successfully
      final firstResult = await firstCall;
      expect(firstResult, isTrue);
      expect(controller.state.isSuccess, isTrue);
    });

    test('repository failure updates state and allows retry', () async {
      repository.shouldFailSubmission = true;

      final controller = BookingReviewController(
        bookingRepository: repository,
        draftId: testDraft.id,
      );
      await Future.delayed(const Duration(milliseconds: 150));

      final success = await controller.submitBooking();

      expect(success, isFalse);
      expect(controller.state.isSubmitting, isFalse);
      expect(controller.state.hasError, isTrue);
      expect(controller.state.errorMessage, contains('timeout'));

      // Fix failure condition and retry
      repository.shouldFailSubmission = false;
      final retrySuccess = await controller.retry();

      expect(retrySuccess, isTrue);
      expect(controller.state.isSuccess, isTrue);
      expect(controller.state.hasError, isFalse);
    });
  });
}
