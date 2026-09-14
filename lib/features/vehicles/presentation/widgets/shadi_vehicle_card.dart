import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_verification_badge.dart';
import '../../../home/presentation/view_models/vehicle_card_view_model.dart';

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
          // Vehicle Image Placeholder
          Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primaryBurgundy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (viewModel.isVerifiedVehicle)
                      const ShadiVerificationBadge(
                        label: 'VERIFIED',
                        isCompact: false,
                      ),
                  ],
                ),
                Text(
                  viewModel.subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
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
                    Text(
                      viewModel.reviewCountText,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                    const Spacer(),
                    if (viewModel.distanceText.isNotEmpty) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.textTertiaryLight,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        viewModel.distanceText,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textTertiaryLight,
                          ),
                        ),
                        RichText(
                          text: TextSpan(
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
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBurgundy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'View Details',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
