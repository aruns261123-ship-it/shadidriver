import 'package:shadidriver/core/result/result.dart';
import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_details.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';

/// Pure Dart domain contract for vehicle catalog and fleet operations.
abstract interface class VehicleRepository {
  Future<Result<List<VehicleSummary>>> getAvailableVehicles({
    String? categoryId,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
  });

  Future<Result<List<VehicleSummary>>> getFeaturedVehicles();

  Future<Result<VehicleSummary>> getVehicleById(String vehicleId);

  Future<Result<VehicleDetails>> getVehicleDetails(String vehicleId);

  Future<Result<List<VehicleSummary>>> searchVehicles({
    required VehicleSearchQuery query,
    required SearchSort sort,
  });
}
