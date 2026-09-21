import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/core/theme/app_colors.dart';
import 'package:shadidriver/core/theme/app_typography.dart';
import 'package:shadidriver/core/widgets/shadi_loading_indicator.dart';
import 'package:shadidriver/core/widgets/shadi_error_view.dart';
import 'package:shadidriver/core/widgets/shadi_empty_state.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';
import 'controllers/search_controller.dart';
import '../domain/entities/search_query.dart';
import '../domain/entities/search_session.dart';
import '../domain/entities/search_sort.dart';
import 'widgets/filter_bottom_sheet.dart';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchControllerProvider);

    // Trigger initial search if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchControllerProvider.notifier).performInitialSearch();
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(context, session),
      body: Column(
        children: [
          _buildFilterBar(context, ref, session),
          Expanded(child: _buildBody(context, ref, session)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    SearchSession session,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.query.pickupLocation ?? 'Delhi NCR',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textPrimaryLight,
            ),
          ),
          Text(
            '${session.query.occasionId ?? "Ceremony"} • ${_formatDate(session.query.eventDate)}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.sort_rounded,
            color: AppColors.primaryBurgundy,
          ),
          onPressed: () => _showSortPicker(context, session),
        ),
      ],
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    SearchSession session,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Filters'),
              onPressed: () => _showFilters(context),
            ),
            const SizedBox(width: 8),
            if (session.query.availableNow)
              _buildFilterChip(
                'Available Now',
                () => _updateQuery(ref, session, availableNow: false),
              ),
            if (session.query.occasionId != null)
              _buildFilterChip(
                session.query.occasionId!,
                () => _updateQuery(
                  ref,
                  session,
                  occasionId: '',
                  occasionCleared: true,
                ),
              ),
            if (session.query.verifiedChauffeurOnly)
              _buildFilterChip(
                'Verified Chauffeur',
                () => _updateQuery(ref, session, verifiedChauffeurOnly: false),
              ),
            if (session.query.transmission != null)
              _buildFilterChip(
                session.query.transmission!,
                () => _updateQuery(ref, session, transmission: null),
              ),
            if (session.query.minRating != null)
              _buildFilterChip(
                '${session.query.minRating}+ ⭐',
                () => _updateQuery(ref, session, minRating: null),
              ),
            if (session.query.seatingCapacities != null)
              ...session.query.seatingCapacities!.map(
                (cap) => _buildFilterChip('$cap+ Seats', () {
                  final newCaps = List<int>.from(
                    session.query.seatingCapacities!,
                  )..remove(cap);
                  _updateQuery(
                    ref,
                    session,
                    seatingCapacities: newCaps.isEmpty ? null : newCaps,
                  );
                }),
              ),
            if (session.query.vehicleCategories != null)
              ...session.query.vehicleCategories!.map(
                (cat) => _buildFilterChip(cat, () {
                  final newCats = List<String>.from(
                    session.query.vehicleCategories!,
                  )..remove(cat);
                  _updateQuery(
                    ref,
                    session,
                    vehicleCategories: newCats.isEmpty ? null : newCats,
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onDeleted) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(label),
        onDeleted: onDeleted,
        deleteIconColor: AppColors.primaryBurgundy,
        backgroundColor: AppColors.secondarySurface,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    SearchSession session,
  ) {
    switch (session.status) {
      case SearchStatus.initial:
      case SearchStatus.loading:
        return const ShadiLoadingIndicator(
          message: 'Searching for your royal ride...',
        );
      case SearchStatus.error:
        return ShadiErrorView(
          message: session.error?.message ?? 'Unknown error occurred',
          onRetry: () => ref
              .read(searchControllerProvider.notifier)
              .updateQuery(session.query),
        );
      case SearchStatus.empty:
        return ShadiEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No Chauffeurs Found',
          description:
              'Try adjusting your filters or changing the date to find available rides.',
          actionLabel: 'Clear All Filters',
          onAction: () =>
              ref.read(searchControllerProvider.notifier).clearFilters(),
        );
      case SearchStatus.loaded:
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: session.results.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${session.results.length} chauffeurs found',
                  style: AppTypography.titleMedium,
                ),
              );
            }
            final vehicle = session.results[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ShadiVehicleCard(
                viewModel: VehicleCardViewModel.fromEntity(vehicle),
                onTap: () {
                  context.push(
                    RoutePaths.customerVehicleDetailsPath(vehicle.id),
                  );
                },
              ),
            );
          },
        );
    }
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  void _showSortPicker(BuildContext context, SearchSession session) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SearchSort.values.map((sort) {
              return ListTile(
                title: Text(sort.displayLabel),
                trailing: session.sort == sort
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryBurgundy,
                      )
                    : null,
                onTap: () {
                  ref.read(searchControllerProvider.notifier).updateSort(sort);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _updateQuery(
    WidgetRef ref,
    SearchSession session, {
    bool? availableNow,
    bool? verifiedChauffeurOnly,
    String? transmission,
    double? minRating,
    List<int>? seatingCapacities,
    List<String>? vehicleCategories,
    String? occasionId,
    bool occasionCleared = false,
  }) {
    final query = session.query.copyWith(
      availableNow: availableNow,
      verifiedChauffeurOnly: verifiedChauffeurOnly,
      transmission: transmission,
      minRating: minRating,
      seatingCapacities: seatingCapacities,
      vehicleCategories: vehicleCategories,
      occasionId: occasionId,
    );
    ref
        .read(searchControllerProvider.notifier)
        .updateQuery(
          occasionCleared
              ? VehicleSearchQuery(
                  pickupLocation: query.pickupLocation,
                  destination: query.destination,
                  eventDate: query.eventDate,
                  eventTime: query.eventTime,
                  passengerCount: query.passengerCount,
                  vehicleCategories: query.vehicleCategories,
                  seatingCapacities: query.seatingCapacities,
                  transmission: query.transmission,
                  minRating: query.minRating,
                  maxDistanceKm: query.maxDistanceKm,
                  verifiedChauffeurOnly: query.verifiedChauffeurOnly,
                  verifiedVehicleOnly: query.verifiedVehicleOnly,
                  availableNow: query.availableNow,
                  amenities: query.amenities,
                  addonIds: query.addonIds,
                )
              : query,
        );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No Date';
    return '${date.day}/${date.month}/${date.year}';
  }
}
