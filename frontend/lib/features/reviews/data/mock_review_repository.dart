import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../domain/entities/review_summary.dart';
import '../domain/repositories/review_repository.dart';

/// Domain representation of a submitted post-ceremony review.
///
/// Kept beside the mock for now; promoted to domain/entities when the
/// customer-side review UI and chauffeur rating aggregation share it.
class SubmittedReview extends ReviewSummary {
  final String bookingId;
  final int? punctualityRating;
  final int? groomingRating;

  const SubmittedReview({
    required this.bookingId,
    required super.id,
    required super.reviewerName,
    required super.rating,
    required super.comment,
    required super.createdAt,
    this.punctualityRating,
    this.groomingRating,
  });
}

/// In-memory mock implementation of ReviewRepository.
///
/// Stores submitted reviews keyed by booking and can flip ratings onto the
/// chauffeur's profile roster entry so earned reviews surface on the
/// Chauffeur Profile (operations-computed, never self-edited).
class MockReviewRepository implements ReviewRepository {
  final List<SubmittedReview> _reviews = [];

  @override
  Future<Result<void>> submitReview({
    required String bookingId,
    required int rating,
    required String feedback,
    int? punctualityRating,
    int? groomingRating,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (rating < 1 || rating > 5) {
      return const Result.failure(
        ValidationFailure('Rating must be between 1 and 5 stars.'),
      );
    }

    _reviews.add(
      SubmittedReview(
        bookingId: bookingId,
        id: 'rev_${bookingId}_$_reviews.length',
        reviewerName: 'Wedding Host',
        rating: rating.toDouble(),
        comment: feedback,
        createdAt: DateTime.now(),
        punctualityRating: punctualityRating,
        groomingRating: groomingRating,
      ),
    );
    return const Result.success(null);
  }

  /// Whether a booking already has a review (drives "Rate Ceremony" vs done).
  bool hasReviewForBooking(String bookingId) =>
      _reviews.any((r) => r.bookingId == bookingId);

  /// Aggregates earned rating/count for a chauffeur.
  ({double rating, int count}) chauffeurRatingSummary(String chauffeurId) {
    if (_reviews.isEmpty) return (rating: 0, count: 0);
    final sum = _reviews.fold<double>(0, (acc, r) => acc + r.rating);
    return (rating: sum / _reviews.length, count: _reviews.length);
  }

  /// All reviews (newest first) — used by tests and future profile surfacing.
  List<SubmittedReview> get allReviews =>
      List.unmodifiable(_reviews);
}
