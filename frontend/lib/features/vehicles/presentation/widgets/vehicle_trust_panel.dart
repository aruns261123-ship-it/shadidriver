import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';

/// Trust panel shown on a customer-facing vehicle page.
///
/// ShadiDriver assigns the chauffeur internally, so the customer is promised a
/// *verified* service without being shown (or able to browse) the chauffeur's
/// identity, photo or rating. The trust signal is the company's verification,
/// not a person profile.
class VehicleTrustPanel extends StatelessWidget {
  /// Whether the backend can source a verified chauffeur for this vehicle.
  final bool hasVerifiedChauffeur;

  const VehicleTrustPanel({super.key, required this.hasVerifiedChauffeur});

  @override
  Widget build(BuildContext context) {
    final points = <(IconData, String, String)>[
      (
        Icons.verified_user_rounded,
        'Vehicle & chauffeur verified by ShadiDriver',
        hasVerifiedChauffeur
            ? 'Every car and chauffeur on this booking is vetted by our team '
                  'before your event.'
            : 'Chauffeur allocation is confirmed by ShadiDriver operations when '
                  'your booking is finalised.',
      ),
      (
        Icons.support_agent_rounded,
        'One point of contact, from enquiry to vidai',
        'ShadiDriver operations manages availability, allocation and '
            'coordination with you — no third-party negotiations.',
      ),
      (
        Icons.visibility_off_rounded,
        'Your privacy is protected',
        'Chauffeur and partner details stay internal. You deal with '
            'ShadiDriver, not with individuals.',
      ),
    ];

    return ShadiCard(
      padding: const EdgeInsets.all(16),
      border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, body) in points) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: AppColors.verifiedEmerald),
                const SizedBox(width: 12),
                // The body text must be free to wrap on a narrow phone.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (icon != points.last.$1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
