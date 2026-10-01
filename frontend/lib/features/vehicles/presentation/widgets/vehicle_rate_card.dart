import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// The reference pricing card (PAGE 02 · Car details): a champagne panel with
/// "Calculated rate" and the per-km figure, plus the transparency caption.
class VehicleRateCard extends StatelessWidget {
  final String rateText;
  final String caption;

  const VehicleRateCard({
    super.key,
    required this.rateText,
    this.caption =
        'Transparent rate based on fuel price and vehicle mileage.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.softChampagne,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Calculated rate',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontSize: 9,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  rateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            style: AppTypography.labelSmall.copyWith(
              fontSize: 8,
              color: const Color(0xFF705B26),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
