import '../../../../core/result/result.dart';
import '../entities/favorites_view.dart';

/// Persistent favourites, always scoped to the authenticated caller on the
/// server. There is no "favourites for another user" call by design.
abstract interface class FavoritesRepository {
  /// Current saved vehicles for the signed-in customer.
  Future<Result<FavoritesView>> list();

  /// Saves a vehicle. Idempotent — saving twice is a success, not an error.
  Future<Result<FavoritesView>> add(String vehicleId);

  /// Removes a vehicle. Idempotent.
  Future<Result<FavoritesView>> remove(String vehicleId);

  /// Imports a signed-out visitor's shortlist into the account. Stale or
  /// unknown ids are reported in `ignoredVehicleIds`, never thrown.
  Future<Result<FavoritesView>> merge(List<String> vehicleIds);
}
