import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../home/presentation/view_models/vehicle_card_view_model.dart';
import '../../vehicles/presentation/widgets/shadi_vehicle_card.dart';
import 'controllers/favorites_controller.dart';

/// The customer's saved vehicles.
///
/// Requires a session: favourites are an account feature. A signed-out visitor
/// keeps a session-local shortlist instead, which is merged the moment they
/// authenticate (see [FavoritesController]).
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    // Reconcile with the server on entry: a saved vehicle may have been
    // suspended, or saved on another device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final vehicles = favorites.view.vehicles;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Saved Vehicles',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
        child: _buildBody(favorites, vehicles),
      ),
    );
  }

  Widget _buildBody(FavoritesState favorites, List<dynamic> vehicles) {
    if (favorites.isSyncing && favorites.savedCount == 0 && vehicles.isEmpty) {
      return const Center(child: ShadiLoadingIndicator());
    }

    if (favorites.errorMessage != null && vehicles.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          ShadiErrorView(
            message: favorites.errorMessage!,
            onRetry: () => ref.read(favoritesProvider.notifier).refresh(),
          ),
        ],
      );
    }

    if (favorites.savedCount == 0) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Icon(
                    Icons.favorite_border_rounded,
                    size: 48,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved vehicles yet',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart on any car to keep it here. '
                    'Browse the fleet to get started.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (favorites.unavailableCount > 0) ...[
          _UnavailableNotice(count: favorites.unavailableCount),
          const SizedBox(height: 12),
        ],
        for (final vehicle in vehicles.cast<dynamic>()) ...[
          ShadiVehicleCard(
            viewModel: VehicleCardViewModel.fromEntity(vehicle),
            onTap: () => context.push(
              RoutePaths.customerVehicleDetailsPath(vehicle.id as String),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// A saved vehicle can leave the catalog (suspended, expired, withdrawn).
/// Those are counted rather than vanishing silently.
class _UnavailableNotice extends StatelessWidget {
  final int count;

  const _UnavailableNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 saved vehicle is no longer available for booking.'
                  : '$count saved vehicles are no longer available for booking.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
