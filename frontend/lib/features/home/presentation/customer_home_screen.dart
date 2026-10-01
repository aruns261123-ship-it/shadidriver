import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_muhurat_countdown_ticker.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_design_system.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../favorites/presentation/controllers/favorites_controller.dart';
import '../../search/domain/entities/search_query.dart';
import '../../search/presentation/controllers/search_controller.dart';
import '../../notifications/presentation/controllers/notifications_controller.dart';
import 'widgets/customer_home_hero.dart';
import 'widgets/route_booking_panel.dart';
import 'widgets/popular_category_card.dart';
import 'widgets/shadi_urgent_dispatch_card.dart';
import 'widgets/shadi_package_card.dart';
import 'widgets/shadi_trust_section.dart';
import '../../vehicles/presentation/widgets/shadi_vehicle_card.dart';
import '../../bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import 'view_models/vehicle_card_view_model.dart';

/// Customer Home, arranged as the reference design's PAGE 02 customer flow:
/// hero → route booking panel → popular categories → suggested vehicle → the
/// ceremonial feed (muhurat ticker, urgent dispatch, featured fleet, packages,
/// assurance, recently viewed).
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  TripDirection _tripDirection = TripDirection.oneWay;

  void _searchByOccasion(String occasion) {
    ref
        .read(searchControllerProvider.notifier)
        .updateQuery(
          VehicleSearchQuery(
            pickupLocation: 'Delhi NCR',
            occasionId: occasion,
            tripType: _tripDirection.wire,
          ),
        );
    context.push(RoutePaths.customerSearchResults);
  }

  void _findCars() {
    // The booking panel's FULL route intent seeds the search exactly as the
    // reference flow does (Home → Route → Eligible Cars): the chosen trip
    // direction is PERSISTED into the search query and travels to the API,
    // the quote, and the booking. Server prices ROUND_TRIP (Both Way) at
    // twice the one-way route distance.
    ref
        .read(searchControllerProvider.notifier)
        .updateQuery(
          VehicleSearchQuery(
            pickupLocation: 'Delhi NCR',
            destination: null,
            occasionId: 'Baraat',
            tripType: _tripDirection.wire,
          ),
        );
    // The guest selection (cart) carries the same intent so it survives the
    // login detour and reaches the booking payload.
    ref.read(guestFleetSelectionProvider.notifier).updateTrip(
          ref.read(guestFleetSelectionProvider).trip.copyWith(
                tripType: _tripDirection.wire,
                city: 'Delhi NCR',
              ),
        );
    context.push(RoutePaths.customerSearchResults);
  }

  /// Cart/review trip-type switch (One Way ↔ Both Way): updates the search
  /// session AND the app-level guest selection, so the server quote and the
  /// booking payload both see the change.
  void _onCartTripChanged(TripDirection direction) {
    setState(() => _tripDirection = direction);
    final type = direction.wire;
    final query = ref.read(searchControllerProvider).query;
    ref
        .read(searchControllerProvider.notifier)
        .updateQuery(query.copyWith(tripType: type));
    ref
        .read(guestFleetSelectionProvider.notifier)
        .updateTrip(
          ref
              .read(guestFleetSelectionProvider)
              .trip
              .copyWith(tripType: type),
        );
  }

  @override
  Widget build(BuildContext context) {
    final featuredVehiclesAsync = ref.watch(featuredVehiclesProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final packagesAsync = ref.watch(serviceAddonsProvider);
    final urgentAvailabilityAsync = ref.watch(
      urgentDispatchAvailabilityProvider,
    );
    final recentlyViewedAsync = ref.watch(recentlyViewedVehiclesProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredVehiclesProvider);
          ref.invalidate(serviceCategoriesProvider);
          ref.invalidate(serviceAddonsProvider);
          ref.invalidate(urgentDispatchAvailabilityProvider);
          ref.invalidate(recentlyViewedVehiclesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CustomerHomeHero(
                unreadCount: unreadCount,
                onNotifications: () =>
                    context.push(RoutePaths.customerNotifications),
              ),
            ),

            // BOOKING PANEL — overlapping the hero.
            SliverToBoxAdapter(
              child: RouteBookingPanel(
                tripDirection: _tripDirection,
                onTripChanged: _onCartTripChanged,
                onFindCars: _findCars,
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // POPULAR CATEGORIES — the reference rail under the panel.
                    const ShadiSectionTitle(
                      title: 'Popular categories',
                      action: 'See all',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    categoriesAsync.when(
                      data: (categories) => SizedBox(
                        height: 118,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final captions = const [
                              'For every road',
                              'Arrive in style',
                              'Always on time',
                            ];
                            return PopularCategoryCard(
                              title: categories[index].name,
                              caption: captions[index % captions.length],
                              imageIndex: index,
                              onTap: () =>
                                  _searchByOccasion(categories[index].name),
                            );
                          },
                        ),
                      ),
                      loading: () => const ShadiLoadingIndicator(size: 24),
                      error: (err, _) => ShadiErrorView(
                        message: 'Failed to load occasions',
                        onRetry: () => ref.refresh(serviceCategoriesProvider),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // SUGGESTED NEAR YOU — first eligible vehicle.
                    const ShadiSectionTitle(title: 'Suggested near you'),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),

            featuredVehiclesAsync.when(
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  );
                }
                final suggested = vehicles.first;
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Builder(
                      builder: (cardContext) {
                        ref.watch(guestFleetSelectionProvider);
                        final selection = ref
                            .read(guestFleetSelectionProvider.notifier)
                            .affordanceFor(
                              vehicleTypeId: suggested.vehicleTypeId,
                              displayName:
                                  '${suggested.make} ${suggested.model}'.trim(),
                              vehicleClass: suggested.vehicleClass,
                              seatingCapacity: suggested.seatingCapacity,
                            );
                        final favorites = ref.watch(favoritesProvider);
                        return ShadiVehicleCard(
                          viewModel:
                              VehicleCardViewModel.fromEntity(suggested),
                          isFavorite: favorites.contains(suggested.id),
                          onToggleFavorite: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(suggested.id),
                          onTap: () => context.push(
                            RoutePaths.customerVehicleDetailsPath(
                              suggested.id,
                            ),
                          ),
                          isSelected: selection.isSelected,
                          selectedQuantity: selection.quantity,
                          onAddToSelection: selection.onAdd,
                          onQuantityChanged: selection.onQuantityChanged,
                          onRemoveSelection: selection.onRemove,
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(child: ShadiLoadingIndicator()),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: ShadiErrorView(
                  message: 'Failed to load featured fleet',
                  onRetry: () => ref.refresh(featuredVehiclesProvider),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.section,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MUHURAT TICKER — kept from the ceremonial feed.
                    const ShadiMuhuratCountdownTicker(
                      ceremonyName: 'Today’s Auspicious Muhurat Lagna',
                      venueName:
                          'Vedic Wedding Astrological Window • Prime Ceremonial Hours',
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // URGENT DISPATCH.
                    urgentAvailabilityAsync.when(
                      data: (availability) => ShadiUrgentDispatchCard(
                        availableCount: availability.availableCount,
                        eta: availability.eta,
                        onTap: () =>
                            context.push(RoutePaths.customerUrgentDispatch),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // FEATURED FLEET.
                    const ShadiSectionHeader(
                      title: 'Featured for Your Celebration',
                      subtitle: 'Elite vehicles handpicked for wedding luxury',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

            featuredVehiclesAsync.when(
              data: (vehicles) {
                final rest = vehicles.length > 1
                    ? vehicles.sublist(1)
                    : const <dynamic>[];
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final vehicle = rest[index] as dynamic;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.lg,
                          ),
                          child: Builder(
                            builder: (cardContext) {
                              ref.watch(guestFleetSelectionProvider);
                              final selection = ref
                                  .read(guestFleetSelectionProvider.notifier)
                                  .affordanceFor(
                                    vehicleTypeId:
                                        vehicle.vehicleTypeId as String,
                                    displayName:
                                        '${vehicle.make} ${vehicle.model}'
                                            .trim(),
                                    vehicleClass:
                                        vehicle.vehicleClass as String,
                                    seatingCapacity:
                                        vehicle.seatingCapacity as int,
                                  );
                              return ShadiVehicleCard(
                                viewModel:
                                    VehicleCardViewModel.fromEntity(vehicle),
                                onTap: () => context.push(
                                  RoutePaths.customerVehicleDetailsPath(
                                    vehicle.id as String,
                                  ),
                                ),
                                isSelected: selection.isSelected,
                                selectedQuantity: selection.quantity,
                                onAddToSelection: selection.onAdd,
                                onQuantityChanged: selection.onQuantityChanged,
                                onRemoveSelection: selection.onRemove,
                              );
                            },
                          ),
                        );
                      },
                      childCount: rest.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: SizedBox.shrink(),
              ),
              error: (_, _) => const SliverToBoxAdapter(
                child: SizedBox.shrink(),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WEDDING PACKAGES.
                    const ShadiSectionHeader(
                      title: 'Wedding Packages',
                      subtitle:
                          'Configurable all-inclusive ceremonial mobility',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    packagesAsync.when(
                      data: (packages) => Column(
                        children: packages
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                ),
                                child: ShadiPackageCard(
                                  package: p,
                                  onTap: () => _searchByOccasion(p.name),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      loading: () => const ShadiLoadingIndicator(size: 24),
                      error: (err, _) => ShadiErrorView(
                        message: 'Failed to load packages',
                        onRetry: () => ref.refresh(serviceAddonsProvider),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // TRUST / ROYAL ASSURANCE.
                    const ShadiTrustSection(),

                    const SizedBox(height: AppSpacing.section),

                    // RECENTLY VIEWED.
                    const ShadiSectionHeader(title: 'Recently Viewed'),
                    const SizedBox(height: AppSpacing.lg),
                    recentlyViewedAsync.when(
                      data: (vehicles) => vehicles.isEmpty
                          ? Text(
                              'Vehicles you open will appear here for quick access.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiaryLight,
                              ),
                            )
                          : SizedBox(
                              height: 148,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: vehicles.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: AppSpacing.md),
                                itemBuilder: (context, index) =>
                                    _RecentlyViewedTile(
                                      viewModel:
                                          VehicleCardViewModel.fromEntity(
                                            vehicles[index],
                                          ),
                                      onTap: () {
                                        context.push(
                                          RoutePaths.customerVehicleDetailsPath(
                                            vehicles[index].id,
                                          ),
                                        );
                                      },
                                    ),
                              ),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: AppSpacing.page),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal tile for the Recently Viewed rail.
class _RecentlyViewedTile extends StatelessWidget {
  final VehicleCardViewModel viewModel;
  final VoidCallback onTap;

  const _RecentlyViewedTile({required this.viewModel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.borderLight,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              viewModel.title,
              style: AppTypography.titleSmall.copyWith(
                color: AppColors.primaryBurgundy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${viewModel.priceText} / ${viewModel.priceUnit}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
