import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../data/mock_review_repository.dart';
import '../../domain/repositories/review_repository.dart';

/// State for the post-ceremony review submission flow.
@immutable
class ReviewSubmissionState {
  final bool isSubmitting;
  final bool submitted;
  final String? errorMessage;

  const ReviewSubmissionState({
    this.isSubmitting = false,
    this.submitted = false,
    this.errorMessage,
  });

  ReviewSubmissionState copyWith({
    bool? isSubmitting,
    bool? submitted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReviewSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitted: submitted ?? this.submitted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller submitting post-ceremony customer reviews.
///
/// Reviews carry an overall rating, free-text feedback, and optional
/// punctuality/grooming sub-ratings that operations surface on the chauffeur
/// profile.
class ReviewController extends StateNotifier<ReviewSubmissionState> {
  final ReviewRepository repository;
  final String bookingId;

  ReviewController({
    required this.repository,
    required this.bookingId,
  }) : super(const ReviewSubmissionState());

  /// Submits the review. Returns true on success.
  Future<bool> submitReview({
    required int rating,
    required String feedback,
    int? punctualityRating,
    int? groomingRating,
  }) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await repository.submitReview(
      bookingId: bookingId,
      rating: rating,
      feedback: feedback,
      punctualityRating: punctualityRating,
      groomingRating: groomingRating,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isSubmitting: false, submitted: true);
        return true;
      },
    );
  }
}

/// Family provider keyed by booking ID.
final reviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewController, ReviewSubmissionState, String>((ref, bookingId) {
  return ReviewController(
    repository: ref.watch(reviewRepositoryProvider),
    bookingId: bookingId,
  );
});

/// Whether a booking has already been reviewed (drives CTA vs "reviewed" tag).
final bookingReviewedProvider = Provider.autoDispose.family<bool, String>((
  ref,
  bookingId,
) {
  final repo = ref.watch(reviewRepositoryProvider) as MockReviewRepository;
  return repo.hasReviewForBooking(bookingId);
});
