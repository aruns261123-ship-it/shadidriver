import '../../../../core/result/result.dart';
import '../../bookings/data/mock_booking_repository.dart';
import '../../bookings/domain/entities/booking_status.dart';
import '../domain/repositories/trip_repository.dart';

/// In-memory mock implementation of TripRepository.
///
/// Single source of truth for trip milestone lifecycle
/// (EN_ROUTE → ARRIVED → TRIP_STARTED → COMPLETED). Writes every stage
/// transition into the shared [MockBookingRepository] so the Chauffeur
/// Console's dashboard card, the Completed Assignments history, and the
/// admin dispatch monitor all stay consistent.
class MockTripRepository implements TripRepository {
  final Map<String, String> _tripStates = {};

  /// Booking store used to mirror milestone stages and mark completion.
  final MockBookingRepository? bookingRepository;

  MockTripRepository({this.bookingRepository});

  @override
  Future<Result<void>> startRouteToPickup(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _tripStates[bookingId] = 'EN_ROUTE';
    _mirrorStage(bookingId, BookingStatus.driverArriving);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markMilestoneArrived(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _tripStates[bookingId] = 'ARRIVED';
    _mirrorStage(bookingId, BookingStatus.arrived);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> startCeremonyTrip(String bookingId, String otp) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _tripStates[bookingId] = 'TRIP_STARTED';
    _mirrorStage(bookingId, BookingStatus.tripStarted);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> completeTrip(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _tripStates[bookingId] = 'COMPLETED';
    bookingRepository?.markBookingCompleted(bookingId);
    return const Result.success(null);
  }

  void _mirrorStage(String bookingId, BookingStatus status) {
    bookingRepository?.updateBookingStage(bookingId, status);
  }
}
