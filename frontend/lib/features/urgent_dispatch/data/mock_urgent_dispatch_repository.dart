import '../../../../core/result/result.dart';
import '../domain/repositories/urgent_dispatch_repository.dart';

/// In-memory mock implementation of UrgentDispatchRepository.
class MockUrgentDispatchRepository implements UrgentDispatchRepository {
  @override
  Future<Result<String>> requestUrgentChauffeur({
    required String serviceCategory,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final dispatchId = 'urg_${DateTime.now().millisecondsSinceEpoch}';
    return Result.success(dispatchId);
  }
}
