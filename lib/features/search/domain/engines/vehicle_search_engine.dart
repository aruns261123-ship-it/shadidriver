import 'package:shadidriver/features/search/domain/entities/search_query.dart';
import 'package:shadidriver/features/search/domain/entities/search_sort.dart';
import 'package:shadidriver/features/vehicles/domain/entities/vehicle_summary.dart';
import 'filter_engine.dart';
import 'sort_engine.dart';

/// Orchestrates the filtering and sorting of vehicles.
abstract final class VehicleSearchEngine {
  static List<VehicleSummary> search({
    required List<VehicleSummary> vehicles,
    required VehicleSearchQuery query,
    required SearchSort sort,
  }) {
    final filtered = FilterEngine.filter(vehicles, query);
    return SortEngine.sort(filtered, sort);
  }
}
