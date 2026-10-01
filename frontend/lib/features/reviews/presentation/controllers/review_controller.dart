import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../core/network/api_response.dart';
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

  ReviewController({required this.repository, required this.bookingId})
    : super(const ReviewSubmissionState());

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
///
/// REAL mode asks the backend (`GET /reviews/mine`, whose items carry
/// `group_booking_id`); MOCK mode asks the in-memory store. A failed lookup
/// resolves to false — the customer simply sees the review CTA again, never a
/// fabricated "already reviewed" state.
final bookingReviewedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, bookingId) async {
    final useMock = ref.watch(
      environmentConfigProvider.select((c) => c.useMockData),
    );
    if (useMock) {
      final repo = ref.watch(reviewRepositoryProvider) as MockReviewRepository;
      return repo.hasReviewForBooking(bookingId);
    }
    try {
      final client = ref.watch(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '${ApiPaths.v1}/reviews/mine',
        queryParameters: {'limit': 50},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      final items = (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>();
      return items.any(
        (r) =>
            (r['group_booking_id'] as String? ?? '') == bookingId &&
            r['status'] != 'REJECTED',
      );
    } catch (_) {
      return false;
    }
  },
);
