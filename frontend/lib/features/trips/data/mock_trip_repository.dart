import '../../../../core/result/result.dart';
import '../domain/repositories/trip_repository.dart';

/// In-memory mock implementation of TripRepository.
class MockTripRepository implements TripRepository {
  final Map<String, String> _tripStates = {};

  @override
  Future<Result<void>> markMilestoneArrived(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _tripStates[bookingId] = 'ARRIVED';
    return const Result.success(null);
  }

  @override
  Future<Result<void>> startCeremonyTrip(String bookingId, String otp) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _tripStates[bookingId] = 'TRIP_STARTED';
    return const Result.success(null);
  }

  @override
  Future<Result<void>> completeTrip(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _tripStates[bookingId] = 'COMPLETED';
    return const Result.success(null);
  }
}
