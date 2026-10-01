import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadidriver/app/router/route_paths.dart';
import 'package:shadidriver/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:shadidriver/core/theme/app_colors.dart';
import 'package:shadidriver/core/theme/app_typography.dart';
import 'package:shadidriver/core/widgets/shadi_loading_indicator.dart';
import 'package:shadidriver/core/widgets/shadi_error_view.dart';
import 'package:shadidriver/core/widgets/shadi_empty_state.dart';
import 'package:shadidriver/core/widgets/shadi_primary_button.dart';
import 'package:shadidriver/features/bookings/domain/entities/guest_fleet_selection.dart';
import 'package:shadidriver/features/home/presentation/view_models/vehicle_card_view_model.dart';
import 'package:shadidriver/features/vehicles/presentation/widgets/shadi_vehicle_card.dart';
import '../../bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import '../domain/entities/search_query.dart';
import 'controllers/search_controller.dart';
import '../domain/entities/search_session.dart';
import '../domain/entities/search_sort.dart';
import 'widgets/filter_bottom_sheet.dart';

/// The reference "Eligible Cars" surface (PAGE 02 · Results): a route appbar
/// (Gurugram to Jaipur · One Way · 237 km), the eligibility summary row, and
/// the vehicle list. A non-empty guest selection pins the reference's
/// selection bar ("2 cars selected · estimated · View cart") above the nav bar.
class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(searchControllerProvider);
    final selection = ref.watch(guestFleetSelectionProvider);

    // Trigger initial search if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchControllerProvider.notifier).performInitialSearch();
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(context, session),
      body: Column(
        children: [
          _buildSummaryRow(context, ref, session),
          if (_hasActiveChips(session)) _buildFilterBar(context, ref, session),
          Expanded(child: _buildBody(context, ref, session)),
        ],
      ),
      // The persistent multi-car selection bar: the guest's always-reachable
      // way into their cart, rendered in the Scaffold's bottomNavigationBar
      // slot (above the shell's nav bar; nothing can cover it).
      bottomNavigationBar: selection.isEmpty
          ? null
          : _EligibleCarsSelectionBar(selection: selection),
    );
  }

  bool _hasActiveChips(SearchSession session) {
    final query = session.query;
    return query.availableNow ||
        query.occasionId != null ||
        query.verifiedChauffeurOnly ||
        query.transmission != null ||
        query.minRating != null ||
        (query.seatingCapacities?.isNotEmpty ?? false) ||
        (query.vehicleCategories?.isNotEmpty ?? false);
  }

  /// The reference "simple appbar": an ivory bar with a bordered round back
  /// button, the trip-summary title block (route bold + `One Way · 237 km`
  /// caption), and a bordered round action button.
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    SearchSession session,
  ) {
    final query = session.query;
    final routeLine = [
      query.pickupLocation ?? 'Delhi NCR',
      if ((query.destination ?? '').isNotEmpty) query.destination!,
    ].join(' to ');

    return AppBar(
      backgroundColor: AppColors.ivory,
      surfaceTintColor: AppColors.ivory,
      automaticallyImplyLeading: false,
      elevation: 0,
      toolbarHeight: 64,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: AppColors.borderLight),
      ),
      titleSpacing: 0,
      title: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _RoundBorderedButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.customerHome),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _tripLine(query),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundBorderedButton(
                icon: Icons.search_rounded,
                tooltip: 'Search',
                onTap: () => _showFilters(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tripLine(VehicleSearchQuery query) {
    final occasion = query.occasionId ?? 'Ceremony';
    final date = _formatDate(query.eventDate);
    return '$occasion · $date';
  }

  /// The reference summary row: "18 cars eligible for your trip" on the
  /// left, bordered pill actions on the right.
  Widget _buildSummaryRow(
    BuildContext context,
    WidgetRef ref,
    SearchSession session,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${session.results.length} cars',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(
                    text: ' eligible for your trip',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _FilterPill(
            icon: Icons.tune_rounded,
            label: 'Filters',
            onTap: () => _showFilters(context),
          ),
          const SizedBox(width: 8),
          _FilterPill(
            icon: Icons.sort_rounded,
            label: 'Sort',
            onTap: () => _showSortPicker(context, session),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref,
    SearchSession session,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 8),
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
                () => _updateQuery(ref, session, clearOccasionId: true),
              ),
            if (session.query.verifiedChauffeurOnly)
              _buildFilterChip(
                'Verified Chauffeur',
                () => _updateQuery(ref, session, verifiedChauffeurOnly: false),
              ),
            if (session.query.transmission != null)
              _buildFilterChip(
                session.query.transmission!,
                () => _updateQuery(ref, session, clearTransmission: true),
              ),
            if (session.query.minRating != null)
              _buildFilterChip(
                '${session.query.minRating}+ ⭐',
                () => _updateQuery(ref, session, clearMinRating: true),
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
          message: 'Finding eligible cars…',
        );
      case SearchStatus.error:
        return ShadiErrorView(
          message: session.error?.message ?? 'Unknown error occurred',
          onRetry: () => ref
              .read(searchControllerProvider.notifier)
              .updateQuery(session.query),
        );
      case SearchStatus.empty:
        // Reference empty state: "No cars available — try another location
        // or trip type."
        return ShadiEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No cars available',
          description: 'Try another location or trip type.',
          actionLabel: 'Clear All Filters',
          onAction: () =>
              ref.read(searchControllerProvider.notifier).clearFilters(),
        );
      case SearchStatus.loaded:
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 20),
          itemCount: session.results.length,
          itemBuilder: (context, index) {
            final vehicle = session.results[index];
            // Watch so that returning from the review screen (or removing a
            // car from the selection bar) repaints every card's state.
            ref.watch(guestFleetSelectionProvider);
            final selection = ref
                .read(guestFleetSelectionProvider.notifier)
                .affordanceFor(
                  vehicleTypeId: vehicle.vehicleTypeId,
                  displayName: '${vehicle.make} ${vehicle.model}'.trim(),
                  vehicleClass: vehicle.vehicleClass,
                  seatingCapacity: vehicle.seatingCapacity,
                );
            final favorites = ref.watch(favoritesProvider);
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: ShadiVehicleCard(
                viewModel: VehicleCardViewModel.fromEntity(vehicle),
                isFavorite: favorites.contains(vehicle.id),
                onToggleFavorite: () =>
                    ref.read(favoritesProvider.notifier).toggle(vehicle.id),
                onTap: () {
                  context.push(
                    RoutePaths.customerVehicleDetailsPath(vehicle.id),
                  );
                },
                // GUEST-FIRST: composing — and un-composing — a multi-vehicle
                // selection never requires an account. The selection lives in
                // the app-level guest model and survives the login detour.
                isSelected: selection.isSelected,
                selectedQuantity: selection.quantity,
                onAddToSelection: selection.onAdd,
                onQuantityChanged: selection.onQuantityChanged,
                onRemoveSelection: selection.onRemove,
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
    bool clearOccasionId = false,
    bool clearTransmission = false,
    bool clearMinRating = false,
  }) {
    final query = session.query.copyWith(
      availableNow: availableNow,
      verifiedChauffeurOnly: verifiedChauffeurOnly,
      transmission: transmission,
      minRating: minRating,
      seatingCapacities: seatingCapacities,
      vehicleCategories: vehicleCategories,
      clearOccasionId: clearOccasionId,
      clearTransmission: clearTransmission,
      clearMinRating: clearMinRating,
    );
    ref
        .read(searchControllerProvider.notifier)
        .updateQuery(query);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Any date';
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// The reference selection bar for the results surface: count + estimate on
/// the left, the burgundy "View Cart" action on the right. It mirrors the
/// shell's [GuestSelectionBar] behaviour but stays INSIDE this route, so it
/// never fights the shell's bar on other tabs.
class _EligibleCarsSelectionBar extends StatelessWidget {
  final GuestFleetSelection selection;

  const _EligibleCarsSelectionBar({required this.selection});

  @override
  Widget build(BuildContext context) {
    final total = selection.totalVehicles;
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$total ${total == 1 ? 'car' : 'cars'} selected',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _summaryLine(selection.lines),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Bounded: ShadiPrimaryButton is full-width by default, which
              // would crash with infinite constraints inside this Row.
              Flexible(
                child: ShadiPrimaryButton(
                  text: 'View Cart',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () =>
                      context.push(RoutePaths.customerGroupBooking),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _summaryLine(List<GuestFleetLine> lines) =>
      lines.map((l) => '${l.displayName} × ${l.quantity}').join(' · ');
}

/// The reference's 35px bordered round appbar action.
class _RoundBorderedButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundBorderedButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 35,
            height: 35,
            child: Icon(icon, size: 18, color: AppColors.primaryBurgundy),
          ),
        ),
      ),
    );
  }
}

/// The reference's bordered pill action ("⚙ Filters").
class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FilterPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.primaryBurgundy),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
