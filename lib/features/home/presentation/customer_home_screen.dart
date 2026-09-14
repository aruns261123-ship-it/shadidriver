import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../app/providers/app_providers.dart';
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

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredVehiclesProvider);
          ref.invalidate(serviceCategoriesProvider);
          ref.invalidate(serviceAddonsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                    const SizedBox(height: 8),
                    Text(
                      'Verified chauffeurs and premium vehicles for every wedding moment.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ShadiSearchCard(onSearch: () {}),

                    const SizedBox(height: 32),

                    // 3. OCCASION SERVICES
                    const ShadiSectionHeader(
                      title: 'Occasion Services',
                      subtitle: 'Tailored mobility for every wedding festivity',
                    ),
                    const SizedBox(height: 16),
                    categoriesAsync.when(
                      data: (categories) => SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) =>
                              ShadiServiceCategoryCard(
                                category: categories[index],
                                onTap: () {},
                              ),
                        ),
                      ),
                      loading: () => const ShadiLoadingIndicator(size: 24),
                      error: (err, _) => ShadiErrorView(
                        message: 'Failed to load occasions',
                        onRetry: () => ref.refresh(serviceCategoriesProvider),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 4. SHADIDRIVER NOW
                    ShadiUrgentDispatchCard(
                      availableCount: 12,
                      eta: '8 mins',
                      onTap: () {},
                    ),

                    const SizedBox(height: 32),

                    // 5. FEATURED FLEET
                    const ShadiSectionHeader(
                      title: 'Featured for Your Celebration',
                      subtitle: 'Elite vehicles handpicked for wedding luxury',
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            featuredVehiclesAsync.when(
              data: (vehicles) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ShadiVehicleCard(
                        viewModel: VehicleCardViewModel.fromEntity(
                          vehicles[index],
                        ),
                        onTap: () {},
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // 6. WEDDING PACKAGES
                    const ShadiSectionHeader(
                      title: 'Wedding Packages',
                      subtitle:
                          'Configurable all-inclusive ceremonial mobility',
                    ),
                    const SizedBox(height: 16),
                    packagesAsync.when(
                      data: (packages) => Column(
                        children: packages
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ShadiPackageCard(
                                  package: p,
                                  onTap: () {},
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

                    const SizedBox(height: 32),

                    // 7. TRUST / ROYAL ASSURANCE
                    const ShadiTrustSection(),

                    const SizedBox(height: 32),

                    // 8. RECENTLY VIEWED
                    const ShadiSectionHeader(title: 'Recently Viewed'),
                    const SizedBox(height: 16),
                    // Just showing one for mock
                    featuredVehiclesAsync.when(
                      data: (vehicles) => vehicles.isNotEmpty
                          ? ShadiVehicleCard(
                              viewModel: VehicleCardViewModel.fromEntity(
                                vehicles.last,
                              ),
                              onTap: () {},
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
              const SizedBox(width: 4),
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
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.primaryBurgundy,
          ),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.only(right: 16, left: 8),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.secondarySurface,
            child: Icon(
              Icons.person_rounded,
              color: AppColors.primaryBurgundy,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}
