import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shadi_badge.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_quantity_stepper.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_design_system.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../bookings/presentation/controllers/guest_fleet_selection_controller.dart';
import '../../favorites/presentation/controllers/favorites_controller.dart';
import 'controllers/recently_viewed_controller.dart';
import 'controllers/vehicle_details_controller.dart';
import 'widgets/vehicle_photo_header.dart';
import 'widgets/vehicle_specs_grid.dart';
import 'widgets/vehicle_rate_card.dart';

/// Vehicle details, arranged as the reference design's Car details page:
/// photo header → eyebrow + verified title → trust line → spec grid → pricing
/// card → amenities → service area, with the persistent bottom action bar
/// (estimated fare + Add to Cart / quantity stepper).
///
/// The guest multi-vehicle selection architecture is untouched: selection
/// state stays derived from [guestFleetSelectionProvider]; the reference
/// "Added → quantity" swap is the same shared line rendered in its two states.
class VehicleDetailsScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleDetailsScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailsProvider(vehicleId));
    final favorites = ref.watch(favoritesProvider);
    final isFavourite = favorites.contains(vehicleId);
    // Rebuilds this screen whenever the SHARED selection changes, so the
    // sticky bar can never show a stale state (e.g. after the car was removed
    // from the review screen or the selection bar). The value itself is read
    // through the controller below, which is the single source of truth.
    ref.watch(guestFleetSelectionProvider);

    // Record this vehicle as recently viewed once its details resolve.
    ref.listen(vehicleDetailsProvider(vehicleId), (previous, next) {
      final vehicle = next.valueOrNull;
      if (vehicle != null) {
        ref.read(recentlyViewedProvider.notifier).track(vehicle.id);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: vehicleAsync.when(
        data: (vehicle) {
          // Derived, never remembered: this screen has no `bool isSelected`.
          final selection = ref
              .read(guestFleetSelectionProvider.notifier)
              .affordanceFor(
                vehicleTypeId: vehicle.vehicleTypeId,
                displayName: '${vehicle.make} ${vehicle.model}'.trim(),
                vehicleClass: vehicle.vehicleClass,
                seatingCapacity: vehicle.seatingCapacity,
              );

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PHOTO HEADER — replaces the old app bar.
                      VehiclePhotoHeader(
                        photoUrls: vehicle.galleryUrls,
                        heroTag: 'vehicle-image-$vehicleId',
                        isFavorite: isFavourite,
                        onToggleFavorite: () {
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

                      Padding(
                        padding: const EdgeInsets.fromLTRB(17, 20, 17, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // EYEBROW — PREMIUM SUV.
                            Text(
                              vehicle.vehicleClass.toUpperCase(),
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warmGold,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // TITLE + VERIFIED badge.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${vehicle.make} ${vehicle.model}',
                                    style: TextStyle(
                                      fontFamily:
                                          AppTypography.ceremonialFontFamily,
                                      fontFamilyFallback: AppTypography
                                          .ceremonialFontFallbacks,
                                      fontSize: 29,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.darkBurgundy,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                if (vehicle.verificationStatus == 'APPROVED' ||
                                    vehicle.verificationStatus == 'VERIFIED')
                                  const ShadiBadge.success('Verified'),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // The reference always shows the trust sentence on
                            // a verified listing — it is the platform's promise,
                            // not a chauffeur flag.
                            if (vehicle.verificationStatus == 'APPROVED' ||
                                vehicle.verificationStatus == 'VERIFIED') ...[
                              const ShadiTrustLine(fontSize: 10),
                              const SizedBox(height: 16),
                            ],

                            // SPEC GRID.
                            VehicleSpecsGrid(
                              specs: [
                                (
                                  icon: Icons.airline_seat_recline_normal_rounded,
                                  label: '${vehicle.seatingCapacity} Seats',
                                ),
                                (icon: Icons.directions_car_rounded, label: vehicle.vehicleClass),
                                (
                                  icon: Icons.settings_rounded,
                                  label: vehicle.transmission == 'MANUAL'
                                      ? 'Manual'
                                      : 'Automatic',
                                ),
                                (icon: Icons.local_gas_station_rounded, label: vehicle.fuelType),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // PRICING.
                            const ShadiSectionHeader(title: 'Pricing'),
                            const SizedBox(height: 12),
                            VehicleRateCard(
                              rateText: vehicle.pricing.isUnavailable
                                  ? 'On request'
                                  : '${CurrencyFormatter.formatPaise(vehicle.pricing.basePriceCents)} / ${vehicle.pricing.billingUnit.toLowerCase()}',
                            ),
                            const SizedBox(height: 24),

                            // AMENITIES.
                            if (vehicle.amenities.isNotEmpty) ...[
                              const ShadiSectionHeader(title: 'Amenities'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: vehicle.amenities
                                    .map(
                                      (a) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppColors.borderLight,
                                          ),
                                        ),
                                        child: Text(
                                          a,
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                            fontSize: 8,
                                            color:
                                                AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // SERVICE AREA.
                            if (vehicle.serviceAreas.isNotEmpty) ...[
                              const ShadiSectionHeader(title: 'Service area'),
                              const SizedBox(height: 12),
                              _ServiceAreaCard(areas: vehicle.serviceAreas),
                              const SizedBox(height: 24),
                            ],

                            // ASSURANCE — managed service, no chauffeur identity.
                            const ShadiSectionHeader(
                              title: 'ShadiDriver Assurance',
                              subtitle: 'Managed by our operations team',
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // STICKY BOTTOM ACTION AREA — estimated fare + Add to Cart.
              _DetailActionBar(
                fareText: vehicle.pricing.isUnavailable
                    ? 'Price on request'
                    : '${CurrencyFormatter.formatPaise(vehicle.pricing.basePriceCents)}+',
                fareUnit: vehicle.pricing.isUnavailable
                    ? ''
                    : vehicle.pricing.billingUnit.toLowerCase(),
                isSelected: selection.isSelected,
                quantity: selection.quantity > 0 ? selection.quantity : 1,
                onAdd: selection.onAdd,
                onQuantityChanged: selection.onQuantityChanged,
                onRemove: selection.onRemove,
                // The existing single-vehicle booking entry stays reachable:
                // Add to Cart composes a multi-car selection, this jumps
                // straight into this vehicle's booking flow.
                onBookDirect: () => context.push(
                  RoutePaths.customerBookingCreatePath(vehicle.id),
                ),
              ),
            ],
          );
        },
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

/// Service-area presentation: champagne radius chip over a neutral map wash
/// with the eligibility explanation from the reference.
class _ServiceAreaCard extends StatelessWidget {
  final List<String> areas;

  const _ServiceAreaCard({required this.areas});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E3D9),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.champagneGold.withValues(alpha: 0.2),
                border: Border.all(color: AppColors.champagneGold),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                color: AppColors.primaryBurgundy,
                size: 18,
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Eligible in ${areas.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 7,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reference `detail-cta`: estimated fare on the left, Add to Cart (or the
/// quantity stepper once added) on the right.
class _DetailActionBar extends StatelessWidget {
  final String fareText;
  final String fareUnit;
  final bool isSelected;
  final int quantity;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onBookDirect;

  const _DetailActionBar({
    required this.fareText,
    required this.fareUnit,
    required this.isSelected,
    required this.quantity,
    this.onAdd,
    this.onQuantityChanged,
    this.onRemove,
    this.onBookDirect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated fare',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiaryLight,
                      fontSize: 8,
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: fareText,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        if (fareUnit.isNotEmpty)
                          TextSpan(
                            text: ' / $fareUnit',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textTertiaryLight,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (onBookDirect != null)
                    TextButton(
                      onPressed: onBookDirect,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primaryBurgundy,
                      ),
                      child: Text(
                        'Book this car now',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ADDED → quantity stepper (the reference's Selected state);
            // otherwise the burgundy Add to Cart. Both operate the SAME
            // shared selection line.
            if (isSelected)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (onQuantityChanged != null)
                    ShadiQuantityStepper(
                      quantity: quantity,
                      onDecrement: () => onQuantityChanged!(quantity - 1),
                      onIncrement: () => onQuantityChanged!(quantity + 1),
                    ),
                  if (onRemove != null)
                    TextButton(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primaryBurgundy,
                      ),
                      child: Text(
                        'Remove',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              )
            else
              // Bounded: ShadiPrimaryButton is full-width by default, which
              // crashes with infinite constraints inside a Row.
              Flexible(
                child: ShadiPrimaryButton(
                  text: 'Add to Cart',
                  onPressed: onAdd,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Secondary single-vehicle booking action, kept from the existing flow and
/// restyled as the reference text action under the fare column.
