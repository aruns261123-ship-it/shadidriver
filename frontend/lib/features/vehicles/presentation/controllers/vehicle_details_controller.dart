import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../domain/entities/vehicle_details.dart';

/// Fetches detailed vehicle specifications and ceremonial suitability by ID.
final vehicleDetailsProvider = FutureProvider.family<VehicleDetails, String>((
  ref,
  vehicleId,
) async {
  final repo = ref.watch(vehicleRepositoryProvider);
  final result = await repo.getVehicleDetails(vehicleId);
  return result.fold((failure) => throw failure, (details) => details);
});

// Favourites moved to `features/favorites`: they are account-backed and
// persistent for signed-in customers, and session-local only for guests. See
// [favoritesProvider]. The old session-only `shortlistProvider` was removed so
// there is a single source of truth for "is this vehicle saved?".
