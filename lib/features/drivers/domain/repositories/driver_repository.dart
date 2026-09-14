import '../../../../core/result/result.dart';
import '../entities/driver_profile.dart';

/// Pure Dart domain contract for chauffeur profile and roster operations.
abstract interface class DriverRepository {
  Future<Result<DriverProfile>> getProfile();

  Future<Result<void>> updateOnlineStatus(bool isOnline);

  Future<Result<void>> submitPreTripChecklist({
    required String bookingId,
    required bool isFuelChecked,
    required bool isDualAcChecked,
    required bool isGroomingChecked,
  });

  Future<Result<void>> sendTelemetryPing({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double bearing,
  });
}
