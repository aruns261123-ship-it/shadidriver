import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../domain/repositories/trip_repository.dart';

/// Real backend trip repository.
///
/// Milestones map onto the booking state machine transitions:
/// START_ROUTE → ARRIVE → START_TRIP (OTP verified server-side against the
/// hashed per-booking trip OTP) → COMPLETE_TRIP. The client can never
/// start a trip without the host's OTP — the server enforces it.
class TripApiRepository implements TripRepository {
  final ApiClient _client;

  TripApiRepository(this._client);

  @override
  Future<Result<void>> startRouteToPickup(String bookingId) =>
      _transition(bookingId, 'START_ROUTE');

  @override
  Future<Result<void>> markMilestoneArrived(String bookingId) =>
      _transition(bookingId, 'ARRIVE');

  @override
  Future<Result<void>> startCeremonyTrip(String bookingId, String otp) =>
      _transition(bookingId, 'START_TRIP', otp: otp);

  @override
  Future<Result<void>> completeTrip(String bookingId) =>
      _transition(bookingId, 'COMPLETE_TRIP');

  Future<Result<void>> _transition(
    String bookingId,
    String action, {
    String? otp,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '${ApiPaths.v1}/bookings/$bookingId/transition',
        data: {
          'action': action,
          'otp': ?otp,
        },
      );
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }
}
