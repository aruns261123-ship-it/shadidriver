import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';

class ShadiUrgentDispatchCard extends StatelessWidget {
  final int availableCount;
  final String eta;
  final VoidCallback onTap;

  const ShadiUrgentDispatchCard({
    super.key,
    required this.availableCount,
    required this.eta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ShadiCard(
      backgroundColor: AppColors.urgentSaffron.withValues(alpha: 0.05),
      border: Border.all(color: AppColors.urgentSaffron.withValues(alpha: 0.3)),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.urgentSaffron,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Need a car right now?',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.urgentSaffron,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nearby verified chauffeurs ready for urgent wedding dispatch.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStat('$availableCount Available'),
                    const SizedBox(width: 16),
                    _buildStat('ETA $eta'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.urgentSaffron,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.urgentSaffron.withValues(alpha: 0.1),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.urgentSaffron,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
