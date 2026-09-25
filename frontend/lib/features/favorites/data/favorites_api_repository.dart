import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../../vehicles/data/dto/public_vehicle_dto.dart';
import '../domain/entities/favorites_view.dart';
import '../domain/repositories/favorites_repository.dart';

/// Real backend implementation of [FavoritesRepository] against
/// `/api/v1/favorites`. Every endpoint requires an authenticated customer; the
/// server derives the account from the bearer token, so no customer id is ever
/// sent from the client.
class FavoritesApiRepository implements FavoritesRepository {
  final ApiClient _client;

  FavoritesApiRepository(this._client);

  static const _basePath = '${AppConstants.apiV1Prefix}/favorites';

  @override
  Future<Result<FavoritesView>> list() => _request(() => _client.get(_basePath));

  @override
  Future<Result<FavoritesView>> add(String vehicleId) =>
      _request(() => _client.post('$_basePath/$vehicleId'));

  @override
  Future<Result<FavoritesView>> remove(String vehicleId) =>
      _request(() => _client.delete('$_basePath/$vehicleId'));

  @override
  Future<Result<FavoritesView>> merge(List<String> vehicleIds) => _request(
    () => _client.post('$_basePath/merge', data: {'vehicleIds': vehicleIds}),
  );

  Future<Result<FavoritesView>> _request(
    Future<dynamic> Function() send,
  ) async {
    try {
      final response = await send();
      final envelope = ApiEnvelope.fromJson(
        response.data as Map<String, dynamic>,
      );
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(_mapView(data));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  FavoritesView _mapView(Map<String, dynamic> data) {
    final vehicles = PublicVehicleDto.toSummaryList(data);
    final ids =
        (data['vehicle_ids'] as List?)?.whereType<String>().toSet() ??
        vehicles.map((v) => v.id).toSet();
    final ignored =
        (data['ignored_vehicle_ids'] as List?)?.whereType<String>().toList() ??
        const <String>[];

    return FavoritesView(
      vehicles: vehicles,
      vehicleIds: ids,
      total: (data['total'] as num?)?.toInt() ?? vehicles.length,
      unavailableCount: (data['unavailable_count'] as num?)?.toInt() ?? 0,
      ignoredVehicleIds: ignored,
    );
  }
}
