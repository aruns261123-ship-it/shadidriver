import '../../../../core/result/result.dart';

/// Pure Dart domain contract for urgent & emergency chauffeur dispatch.
abstract interface class UrgentDispatchRepository {
  Future<Result<String>> requestUrgentChauffeur({
    required String serviceCategory,
    required double latitude,
    required double longitude,
    required String address,
  });
}
