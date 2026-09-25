import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../favorites/presentation/controllers/favorites_controller.dart';
import 'controllers/recently_viewed_controller.dart';
import 'controllers/vehicle_details_controller.dart';
import 'widgets/technical_specs_grid.dart';
import 'widgets/vehicle_gallery.dart';
import 'widgets/vehicle_trust_panel.dart';

class VehicleDetailsScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleDetailsScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailsProvider(vehicleId));
    final favorites = ref.watch(favoritesProvider);
    final isFavourite = favorites.contains(vehicleId);

    // Record this vehicle as recently viewed once its details resolve.
    ref.listen(vehicleDetailsProvider(vehicleId), (previous, next) {
      final vehicle = next.valueOrNull;
      if (vehicle != null) {
        ref.read(recentlyViewedProvider.notifier).track(vehicle.id);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: vehicleAsync.when(
          data: (vehicle) => Text(
            '${vehicle.make} ${vehicle.model}',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryBurgundy,
            ),
          ),
          loading: () => const Text('Loading Details...'),
          error: (err, stack) => const Text('Vehicle Details'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isFavourite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: isFavourite
                  ? AppColors.primaryBurgundy
                  : AppColors.textTertiaryLight,
            ),
            tooltip: isFavourite
                ? 'Remove from favourites'
                : 'Save to favourites',
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggle(vehicleId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isFavourite
                        ? 'Removed from Favourites'
                        : favorites.isAccountBacked
                        ? 'Saved to your favourites'
                        : 'Saved for this session — sign in to keep them',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: vehicleAsync.when(
        data: (vehicle) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interactive Vehicle Image Gallery — heroes in from the card.
                    VehicleGallery(
                      imageUrls: vehicle.galleryUrls,
                      heroTag: 'vehicle-image-$vehicleId',
                    ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Header Info
                          Text(
                            '${vehicle.make} ${vehicle.model}',
                            style: AppTypography.displaySmall.copyWith(
                              color: AppColors.primaryBurgundy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${vehicle.year} • ${vehicle.vehicleClass}',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Rating and Reviews
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: AppColors.champagneGold,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vehicle.rating.toStringAsFixed(1),
                                style: AppTypography.labelSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${vehicle.reviewCount} Reviews)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Technical Specs Grid
                          TechnicalSpecsGrid(vehicle: vehicle),
                          const SizedBox(height: 28),

                          // Ceremonial Suitability
                          const ShadiSectionHeader(
                            title: 'Ceremonial Suitability',
                            subtitle:
                                'Designed for regal entries and procession flow',
                          ),
                          const SizedBox(height: 12),
                          ShadiCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.suitabilityInfo,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimaryLight,
                                    height: 1.5,
                                  ),
                                ),
                                if (vehicle.suitableCeremonies.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: vehicle.suitableCeremonies
                                        .map(
                                          (ceremony) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondarySurface,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppColors.champagneGold
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              ceremony,
                                              style: AppTypography.labelSmall
                                                  .copyWith(
                                                    color: AppColors
                                                        .primaryBurgundy,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Amenities
                          if (vehicle.amenities.isNotEmpty) ...[
                            const ShadiSectionHeader(
                              title: 'Luxury Amenities',
                              subtitle:
                                  'In-cabin features for guest & bridal comfort',
                            ),
                            const SizedBox(height: 12),
                            ShadiCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: vehicle.amenities
                                    .map(
                                      (amenity) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              size: 18,
                                              color: AppColors.verifiedEmerald,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                amenity,
                                                style: AppTypography.bodyMedium
                                                    .copyWith(
                                                      color: AppColors
                                                          .textPrimaryLight,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // Ceremonial Addons
                          if (vehicle.ceremonialAddons.isNotEmpty) ...[
                            const ShadiSectionHeader(
                              title: 'Ceremonial Enhancements',
                              subtitle:
                                  'Optional attire and floral tie-ups available',
                            ),
                            const SizedBox(height: 12),
                            ...vehicle.ceremonialAddons.map(
                              (addon) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ShadiCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              addon.name,
                                              style: AppTypography.titleSmall
                                                  .copyWith(
                                                    color: AppColors
                                                        .primaryBurgundy,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.formatPaise(
                                              addon.pricing.basePriceCents,
                                            ),
                                            style: AppTypography.titleSmall
                                                .copyWith(
                                                  color: AppColors.warmGold,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        addon.description,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],

                          // ShadiDriver assigns the chauffeur internally; the
                          // customer is promised a verified service and never
                          // shown (or able to browse) a chauffeur profile.
                          const ShadiSectionHeader(
                            title: 'ShadiDriver Assurance',
                            subtitle: 'Managed by our operations team',
                          ),
                          const SizedBox(height: 12),
                          VehicleTrustPanel(
                            hasVerifiedChauffeur:
                                vehicle.hasVerifiedChauffeur,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom CTA Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Starting from',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiaryLight,
                          ),
                        ),
                        // A vehicle with no published tariff must never be
                        // advertised at Rs 0.
                        if (vehicle.pricing.isUnavailable)
                          Text(
                            'Price on request',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: CurrencyFormatter.formatPaise(
                                    vehicle.pricing.basePriceCents,
                                  ),
                                  style: AppTypography.titleLarge.copyWith(
                                    color: AppColors.primaryBurgundy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / ${vehicle.pricing.billingUnit}',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ShadiPrimaryButton(
                        text: 'Book Now',
                        onPressed: () {
                          context.push(
                            RoutePaths.customerBookingCreatePath(vehicle.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const ShadiLoadingIndicator(
          message: 'Loading royal specs & chauffeur info...',
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Vehicle specifications could not be found.',
          onRetry: () => ref.refresh(vehicleDetailsProvider(vehicleId)),
        ),
      ),
    );
  }
}
