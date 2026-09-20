import '../../../../core/result/result.dart';
import '../entities/service_addon.dart';

abstract interface class ServiceAddonRepository {
  Future<Result<List<ServiceAddon>>> getAddons();
}
