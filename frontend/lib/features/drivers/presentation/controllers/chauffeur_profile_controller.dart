import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/driver_profile.dart';

/// Fetches detailed chauffeur credentials, ceremonial experience, and reviews by ID.
final chauffeurProfileProvider = FutureProvider.family<DriverProfile, String>((
  ref,
  driverId,
) async {
  final repo = ref.watch(driverRepositoryProvider);
  final result = await repo.getDriverById(driverId);
  return result.fold((failure) => throw failure, (profile) => profile);
});
