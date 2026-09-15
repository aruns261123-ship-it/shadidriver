import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/booking_submission_request.dart';
import '../../domain/entities/booking_submission_result.dart';
import '../../domain/repositories/booking_repository.dart';

/// State representing the booking review and submission lifecycle.
@immutable
class BookingReviewState {
  final BookingDraft? draft;
  final bool isLoadingDraft;
  final bool isSubmitting;
  final BookingSubmissionResult? submissionResult;
  final String? errorMessage;
  final String idempotencyKey;

  const BookingReviewState({
    this.draft,
    this.isLoadingDraft = false,
    this.isSubmitting = false,
    this.submissionResult,
    this.errorMessage,
    required this.idempotencyKey,
  });

  bool get isSuccess => submissionResult != null;
  bool get hasError => errorMessage != null;

  BookingReviewState copyWith({
    BookingDraft? draft,
    bool? isLoadingDraft,
    bool? isSubmitting,
    BookingSubmissionResult? submissionResult,
    String? errorMessage,
    String? idempotencyKey,
    bool clearError = false,
  }) {
    return BookingReviewState(
      draft: draft ?? this.draft,
      isLoadingDraft: isLoadingDraft ?? this.isLoadingDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionResult: submissionResult ?? this.submissionResult,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// Controller managing booking review data and server submission.
///
/// Ensures double-tap protection and carries a deterministic idempotency key.
class BookingReviewController extends StateNotifier<BookingReviewState> {
  final BookingRepository bookingRepository;

  BookingReviewController({
    required this.bookingRepository,
    required String draftId,
    String? initialIdempotencyKey,
  }) : super(
         BookingReviewState(
           isLoadingDraft: true,
           idempotencyKey:
               initialIdempotencyKey ??
               'idem_${draftId}_${DateTime.now().millisecondsSinceEpoch}',
         ),
       ) {
    _loadDraft(draftId);
  }

  Future<void> _loadDraft(String draftId) async {
    final result = await bookingRepository.getBookingDraft(draftId);
    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingDraft: false,
          errorMessage: failure.message,
        );
      },
      (draft) {
        if (draft == null) {
          state = state.copyWith(
            isLoadingDraft: false,
            errorMessage: 'Booking draft not found.',
          );
        } else {
          state = state.copyWith(
            isLoadingDraft: false,
            draft: draft,
            clearError: true,
          );
        }
      },
    );
  }

  /// Submits the customer booking intent.
  ///
  /// Protected against double-taps by verifying `isSubmitting`.
  Future<bool> submitBooking() async {
    // 1. Double-tap and concurrent submission protection
    if (state.isSubmitting) {
      return false;
    }

    final draft = state.draft;
    if (draft == null || !draft.isComplete) {
      state = state.copyWith(
        errorMessage:
            'Booking draft is incomplete. Please return to edit missing details.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    // 2. Build explicit submission request with idempotency key
    final request = BookingSubmissionRequest.fromDraft(
      draft,
      idempotencyKey: state.idempotencyKey,
    );

    // 3. Delegate to repository
    final result = await bookingRepository.submitBooking(request);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (submissionResult) {
        state = state.copyWith(
          isSubmitting: false,
          submissionResult: submissionResult,
          clearError: true,
        );
        return true;
      },
    );
  }

  /// Retries a previously failed submission using the same idempotency key.
  Future<bool> retry() => submitBooking();
}

/// Provider family for BookingReviewController keyed by draft ID.
final bookingReviewControllerProvider =
    StateNotifierProvider.family<
      BookingReviewController,
      BookingReviewState,
      String
    >((ref, draftId) {
      final repo = ref.watch(bookingRepositoryProvider);
      return BookingReviewController(bookingRepository: repo, draftId: draftId);
    });
