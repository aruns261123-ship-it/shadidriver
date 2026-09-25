import '../../../core/result/result.dart';
import '../../vehicles/domain/entities/vehicle_summary.dart';
import '../../vehicles/domain/repositories/vehicle_repository.dart';
import '../domain/entities/favorites_view.dart';
import '../domain/repositories/favorites_repository.dart';

/// In-memory favourites for `useMockData` mode and automated tests ONLY.
/// The production path always uses [FavoritesApiRepository].
class MockFavoritesRepository implements FavoritesRepository {
  MockFavoritesRepository({this.vehicles});

  /// Used to resolve saved ids into displayable vehicles in mock mode.
  final VehicleRepository? vehicles;
  final Set<String> _saved = <String>{};

  /// Test seam: pretend to already have saved vehicles.
  void seed(Iterable<String> vehicleIds) {
    _saved
      ..clear()
      ..addAll(vehicleIds);
  }

  @override
  Future<Result<FavoritesView>> list() async => Result.success(await _view());

  @override
  Future<Result<FavoritesView>> add(String vehicleId) async {
    _saved.add(vehicleId);
    return Result.success(await _view());
  }

  @override
  Future<Result<FavoritesView>> remove(String vehicleId) async {
    _saved.remove(vehicleId);
    return Result.success(await _view());
  }

  @override
  Future<Result<FavoritesView>> merge(List<String> vehicleIds) async {
    _saved.addAll(vehicleIds);
    return Result.success(await _view());
  }

  Future<FavoritesView> _view() async {
    final resolved = <VehicleSummary>[];
    final repo = vehicles;
    if (repo != null && _saved.isNotEmpty) {
      final result = await repo.getAvailableVehicles();
      final all = result.dataOrNull ?? const <VehicleSummary>[];
      for (final id in _saved) {
        final match = all.where((v) => v.id == id);
        if (match.isNotEmpty) resolved.add(match.first);
      }
    }
    return FavoritesView(
      vehicles: resolved,
      vehicleIds: Set<String>.from(_saved),
      total: _saved.length,
      unavailableCount: _saved.length - resolved.length,
    );
  }
}
