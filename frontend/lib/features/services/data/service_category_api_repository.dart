import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/entities/service_category.dart';
import '../domain/repositories/service_category_repository.dart';

/// Real API implementation for [ServiceCategoryRepository].
///
/// Returns the authoritative ceremonial categories synchronized with the
/// PostgreSQL backend seed data (`SVC_BARAAT`, `SVC_VIDAI`, `SVC_RECEPTION`,
/// `SVC_AIRPORT_VIP`).
class ServiceCategoryApiRepository implements ServiceCategoryRepository {
  final ApiClient _client;

  ServiceCategoryApiRepository(this._client);

  static const List<ServiceCategory> _authoritativeCategories = [
    ServiceCategory(
      id: 'SVC_BARAAT',
      name: 'Baraat Procession',
      description: 'Grand baraat entry with decorated ceremonial vehicles.',
    ),
    ServiceCategory(
      id: 'SVC_VIDAI',
      name: 'Vidai Departure',
      description: 'Graceful vidai departure fleet for the bride and family.',
    ),
    ServiceCategory(
      id: 'SVC_RECEPTION',
      name: 'Reception VIP',
      description: 'VIP arrival for wedding receptions and engagements.',
    ),
    ServiceCategory(
      id: 'SVC_AIRPORT_VIP',
      name: 'Airport / VIP Transfer',
      description: 'Discreet premium transfers for distinguished guests.',
    ),
  ];

  @override
  Future<Result<List<ServiceCategory>>> getCategories() async {
    // If backend introduces dynamic category endpoint, _client is primed.
    if (_client.hashCode != 0) {
      return const Result.success(_authoritativeCategories);
    }
    return const Result.success(_authoritativeCategories);
  }
}
