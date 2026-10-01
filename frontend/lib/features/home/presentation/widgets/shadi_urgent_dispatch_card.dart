import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';

/// Urgent-dispatch promotion on the customer home feed.
///
/// RESPONSIVE CONTRACT: the title is bounded by an [Expanded] (it wraps to as
/// many lines as it needs — the card is in a scrollable, so its height is
/// intrinsic) and the stat chips live in a [Wrap], which flows them onto a
/// second line instead of pushing past the card edge. Previously the title
/// `Text` sat unbounded beside its icon (129px of overflow at 360dp) and the
/// stats sat in a fixed `Row` (71px). Nothing is clipped or ellipsized here.
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.urgentSaffron,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    // Bounded, so the headline wraps rather than overflowing.
                    Expanded(
                      child: Text(
                        'Need a car right now?',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.urgentSaffron,
                        ),
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
                // Wrap, not Row: on a compact phone the two chips flow onto a
                // second line instead of being squeezed past the card edge.
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildStat('$availableCount Available'),
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
