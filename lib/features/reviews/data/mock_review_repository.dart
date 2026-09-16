import '../../../../core/result/result.dart';
import '../domain/repositories/review_repository.dart';

/// In-memory mock implementation of ReviewRepository.
class MockReviewRepository implements ReviewRepository {
  final List<Map<String, dynamic>> _reviews = [];

  @override
  Future<Result<void>> submitReview({
    required String bookingId,
    required int rating,
    required String feedback,
    int? punctualityRating,
    int? groomingRating,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _reviews.add({
      'bookingId': bookingId,
      'rating': rating,
      'feedback': feedback,
      'punctualityRating': punctualityRating,
      'groomingRating': groomingRating,
      'submittedAt': DateTime.now(),
    });
    return const Result.success(null);
  }
}
