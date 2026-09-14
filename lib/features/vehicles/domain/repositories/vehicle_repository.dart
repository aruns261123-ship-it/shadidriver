import '../../../../core/result/result.dart';
import '../entities/vehicle_summary.dart';

/// Pure Dart domain contract for vehicle catalog and fleet operations.
abstract interface class VehicleRepository {
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  });

  Future<Result<List<VehicleSummary>>> getFeaturedVehicles();

  Future<Result<VehicleSummary>> getVehicleById(String vehicleId);
}
