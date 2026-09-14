import '../../../../core/result/result.dart';
import '../entities/vehicle_summary.dart';

/// Pure Dart domain contract for vehicle catalog and fleet operations.
abstract interface class VehicleRepository {
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    required String categoryId,
    required DateTime eventStartTime,
    required DateTime eventEndTime,
  });

  Future<Result<VehicleSummary>> getVehicleById(String vehicleId);
}
