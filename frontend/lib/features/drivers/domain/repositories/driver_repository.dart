import '../../../../core/result/result.dart';
import '../entities/driver_duty_status.dart';
import '../entities/driver_profile.dart';

/// Pure Dart domain contract for chauffeur profile and roster operations.
abstract interface class DriverRepository {
  Future<Result<DriverProfile>> getProfile();

  Future<Result<DriverProfile>> getDriverById(String driverId);

  Future<Result<DriverProfile>> updateDriverProfile(DriverProfile profile);

  Future<Result<DriverDutyStatus>> getDutyStatus(String driverId);

  /// Fetches the operational duty status of every chauffeur in the roster.
  ///
  /// Used by the admin Operations Command Room to compute the live
  /// "Chauffeurs On-Duty" KPI from real dispatch state.
  Future<Result<Map<String, DriverDutyStatus>>> getAllDutyStatuses();

  Future<Result<void>> updateDutyStatus({
    required String driverId,
    required DriverDutyStatus status,
  });

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
