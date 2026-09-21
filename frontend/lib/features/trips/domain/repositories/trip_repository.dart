import '../../../../core/result/result.dart';

/// Pure Dart domain contract for active trip telemetry and milestones.
///
/// The chauffeur trip console drives ALL milestone transitions through this
/// contract — never by mutating booking stores directly — so the real backend
/// swap touches exactly one implementation.
abstract interface class TripRepository {
  /// Marks the chauffeur en route to the pickup venue (EN_ROUTE stage).
  Future<Result<void>> startRouteToPickup(String bookingId);

  /// Marks the chauffeur arrived at the venue gate (ARRIVED stage).
  Future<Result<void>> markMilestoneArrived(String bookingId);

  /// Verifies the host start OTP and begins the ceremony (TRIP_STARTED stage).
  Future<Result<void>> startCeremonyTrip(String bookingId, String otp);

  /// Concludes the ceremonial service (COMPLETED stage).
  Future<Result<void>> completeTrip(String bookingId);
}
