import '../../../../core/result/result.dart';

/// Pure Dart domain contract for post-ceremony customer reviews.
abstract interface class ReviewRepository {
  Future<Result<void>> submitReview({
    required String bookingId,
    required int rating,
    required String feedback,
    int? punctualityRating,
    int? groomingRating,
  });
}
