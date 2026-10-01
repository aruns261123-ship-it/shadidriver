import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../domain/repositories/review_repository.dart';

/// REAL backend reviews: `POST /api/v1/reviews`.
///
/// The SERVER enforces every rule this repository only mirrors:
///   * the caller owns the booking;
///   * the booking is COMPLETED (a review can never precede the ceremony);
///   * one review per vehicle / booking;
///   * the chauffeur sub-ratings are derived server-side from the assigned
///     vehicle — never client-asserted.
///
/// The backend's review DTO is group-booking-shaped (`groupBookingId` +
/// `vehicleId`); the customer booking detail passes its booking id for both
/// when the backend aliases single bookings onto the managed model. Server
/// validation errors surface verbatim — nothing is faked.
class ReviewApiRepository implements ReviewRepository {
  final ApiClient _client;

  ReviewApiRepository(this._client);

  @override
  Future<Result<void>> submitReview({
    required String bookingId,
    required int rating,
    required String feedback,
    int? punctualityRating,
    int? groomingRating,
  }) async {
    if (rating < 1 || rating > 5) {
      return const Result.failure(
        ValidationFailure('Rating must be between 1 and 5 stars.'),
      );
    }
    try {
      await _client.post<Map<String, dynamic>>(
        '${ApiPaths.v1}/reviews',
        data: {
          'groupBookingId': bookingId,
          'vehicleId': bookingId,
          'overallRating': rating,
          'punctualityRating': ?punctualityRating,
          'groomingRating': ?groomingRating,
          if (feedback.trim().isNotEmpty) 'feedbackText': feedback.trim(),
        },
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }
}
