import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../search/domain/entities/search_query.dart';
import '../../search/presentation/controllers/search_controller.dart';
import '../../notifications/presentation/controllers/notifications_controller.dart';
import 'widgets/shadi_search_card.dart';
import 'widgets/shadi_service_category_card.dart';
import 'widgets/shadi_urgent_dispatch_card.dart';
import 'widgets/shadi_package_card.dart';
import 'widgets/shadi_trust_section.dart';
import '../../vehicles/presentation/widgets/shadi_vehicle_card.dart';
import 'view_models/vehicle_card_view_model.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredVehiclesAsync = ref.watch(featuredVehiclesProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final packagesAsync = ref.watch(serviceAddonsProvider);
    final urgentAvailabilityAsync = ref.watch(
      urgentDispatchAvailabilityProvider,
    );
    final recentlyViewedAsync = ref.watch(recentlyViewedVehiclesProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    void searchByOccasion(String occasion) {
      ref
          .read(searchControllerProvider.notifier)
          .updateQuery(
            VehicleSearchQuery(
              pickupLocation: 'Delhi NCR',
              occasionId: occasion,
            ),
          );
      context.push(RoutePaths.customerSearchResults);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(context, ref, unreadCount),
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
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. HERO / WEDDING SEARCH
                    Text(
                      'Find the perfect ride for your celebration',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.primaryBurgundy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Verified chauffeurs and premium vehicles for every wedding moment.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    ShadiSearchCard(
                      onSearch: () {
                        searchByOccasion('Baraat');
                      },
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // 3. OCCASION SERVICES
                    const ShadiSectionHeader(
                      title: 'Occasion Services',
                      subtitle: 'Tailored mobility for every wedding festivity',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    categoriesAsync.when(
                      data: (categories) => SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: AppSpacing.lg),
                          itemBuilder: (context, index) =>
                              ShadiServiceCategoryCard(
                                category: categories[index],
                                onTap: () =>
                                    searchByOccasion(categories[index].name),
                              ),
                        ),
                      ),
                      loading: () => const ShadiLoadingIndicator(size: 24),
                      error: (err, _) => ShadiErrorView(
                        message: 'Failed to load occasions',
                        onRetry: () => ref.refresh(serviceCategoriesProvider),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.section),

                    // 4. SHADIDRIVER NOW — counts derived from fleet data
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

                    // 5. FEATURED FLEET
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
              data: (vehicles) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: ShadiVehicleCard(
                        viewModel: VehicleCardViewModel.fromEntity(
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
                    childCount: vehicles.length,
                  ),
                ),
              ),
              loading: () =>
                  const SliverToBoxAdapter(child: ShadiLoadingIndicator()),
              error: (err, _) => SliverToBoxAdapter(
                child: ShadiErrorView(
                  message: 'Failed to load featured fleet',
                  onRetry: () => ref.refresh(featuredVehiclesProvider),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // 6. WEDDING PACKAGES
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
                                  onTap: () => searchByOccasion(p.name),
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

                    // 7. TRUST / ROYAL ASSURANCE
                    const ShadiTrustSection(),

                    const SizedBox(height: AppSpacing.section),

                    // 8. RECENTLY VIEWED — real session history
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

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    int unreadCount,
  ) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.champagneGold,
                size: 14,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'DELHI NCR',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiaryLight,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Text(
            'ShadiDriver',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.primaryBurgundy,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: AppColors.urgentSaffron,
            textColor: Colors.white,
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primaryBurgundy,
            ),
          ),
          onPressed: () => context.push(RoutePaths.customerNotifications),
        ),
        Padding(
          padding: const EdgeInsets.only(
            right: AppSpacing.xl,
            left: AppSpacing.sm,
          ),
          child: GestureDetector(
            key: const Key('driver_portal_shortcut_btn'),
            onTap: () => context.go(RoutePaths.driver),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.secondarySurface,
              child: Icon(
                Icons.directions_car_rounded,
                color: AppColors.primaryBurgundy,
                size: 20,
              ),
            ),
          ),
        ),
      ],
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
