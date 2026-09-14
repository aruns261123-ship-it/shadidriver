import '../../../../core/result/result.dart';

/// Pure Dart domain contract for active trip telemetry and milestones.
abstract interface class TripRepository {
  Future<Result<void>> markMilestoneArrived(String bookingId);
  Future<Result<void>> startCeremonyTrip(String bookingId, String otp);
  Future<Result<void>> completeTrip(String bookingId);
}
