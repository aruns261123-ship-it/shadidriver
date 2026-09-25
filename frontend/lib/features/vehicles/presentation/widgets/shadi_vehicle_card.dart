import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_verification_badge.dart';
import '../../../home/presentation/view_models/vehicle_card_view_model.dart';

/// Vehicle result card used by the home carousel and the search results list.
///
/// Layout contract: every text run is either [Flexible]/[Expanded] or bounded
/// and ellipsized, so real backend values (long model names, UUID ids, long
/// billing units, increased system text scale) can never produce a
/// `RenderFlex overflow`. Verified by
/// `test/features/vehicles/vehicle_card_responsive_test.dart`.
class ShadiVehicleCard extends StatelessWidget {
  final VehicleCardViewModel viewModel;
  final VoidCallback onTap;

  const ShadiVehicleCard({
    super.key,
    required this.viewModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Image Placeholder — heroes into the details gallery.
          Hero(
            tag: 'vehicle-image-${viewModel.id}',
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Icon(
                Icons.directions_car_rounded,
                size: 64,
                color: AppColors.borderLight,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------- title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primaryBurgundy,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (viewModel.isVerifiedVehicle) ...[
                      const SizedBox(width: 8),
                      const Flexible(
                        child: ShadiVerificationBadge(
                          label: 'VERIFIED',
                          isCompact: false,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  viewModel.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // ------------------------------------- rating + distance
                // Two flexible groups: the rating block and the distance chip
                // each give way instead of forcing a horizontal overflow.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.champagneGold,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            viewModel.ratingText,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              viewModel.reviewCountText,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (viewModel.distanceText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.textTertiaryLight,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                viewModel.distanceText,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 8),

                // -------------------------------------- price + action
                // The price is full width and the action sits on its own row.
                // Nothing competes for horizontal space, so a long billing
                // unit or a large system text scale cannot push the row past
                // the card edge (the old side-by-side row overflowed).
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: viewModel.priceText,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' ${viewModel.priceUnit}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // The whole card is tappable; this is its affordance.
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBurgundy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'View Details',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
