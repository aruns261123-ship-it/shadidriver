import '../../../../core/result/result.dart';
import '../../bookings/data/mock_booking_repository.dart';
import '../domain/repositories/trip_repository.dart';

/// In-memory mock implementation of TripRepository.
///
/// Simulates the trip milestone lifecycle (ARRIVED → TRIP_STARTED → COMPLETED)
/// and records completed bookings into the shared [MockBookingRepository] store
/// so the Chauffeur Console's "Completed Assignments" section stays consistent.
class MockTripRepository implements TripRepository {
  final Map<String, String> _tripStates = {};

  /// Booking store used to mark bookings as COMPLETED.
  final MockBookingRepository? bookingRepository;

  MockTripRepository({this.bookingRepository});

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
    bookingRepository?.markBookingCompleted(bookingId);
    return const Result.success(null);
  }
}
