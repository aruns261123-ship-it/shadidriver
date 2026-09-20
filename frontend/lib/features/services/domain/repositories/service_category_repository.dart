import '../../../../core/result/result.dart';
import '../entities/service_category.dart';

abstract interface class ServiceCategoryRepository {
  Future<Result<List<ServiceCategory>>> getCategories();
}
