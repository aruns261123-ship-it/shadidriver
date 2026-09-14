import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/vehicle_details.dart';

/// Fetches detailed vehicle specifications and ceremonial suitability by ID.
final vehicleDetailsProvider =
    FutureProvider.family<VehicleDetails, String>((ref, vehicleId) async {
  final repo = ref.watch(vehicleRepositoryProvider);
  final result = await repo.getVehicleDetails(vehicleId);
  return result.fold(
    (failure) => throw failure,
    (details) => details,
  );
});

/// Session-scoped shortlist state notifier.
/// Tracks vehicles saved by the user during the active session.
class ShortlistNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String vehicleId) {
    if (state.contains(vehicleId)) {
      state = {...state}..remove(vehicleId);
    } else {
      state = {...state, vehicleId};
    }
  }

  void add(String vehicleId) {
    state = {...state, vehicleId};
  }

  void remove(String vehicleId) {
    state = {...state}..remove(vehicleId);
  }

  bool isShortlisted(String vehicleId) => state.contains(vehicleId);

  void clear() {
    state = const {};
  }
}

final shortlistProvider =
    NotifierProvider<ShortlistNotifier, Set<String>>(ShortlistNotifier.new);
