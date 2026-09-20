import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_verification_badge.dart';
import '../../../drivers/presentation/controllers/chauffeur_profile_controller.dart';

/// Preview card displaying the verified chauffeur assigned to a vehicle.
/// Tapping navigates to the full chauffeur profile.
class ChauffeurPreviewCard extends ConsumerWidget {
  final String chauffeurId;
  final VoidCallback onTap;

  const ChauffeurPreviewCard({
    super.key,
    required this.chauffeurId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chauffeurAsync = ref.watch(chauffeurProfileProvider(chauffeurId));

    return chauffeurAsync.when(
      data: (chauffeur) {
        return ShadiCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          border: Border.all(
            color: AppColors.champagneGold.withValues(alpha: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.secondarySurface,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: AppColors.primaryBurgundy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              chauffeur.fullName,
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primaryBurgundy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (chauffeur.verificationStatus == 'VERIFIED')
                              const ShadiVerificationBadge(
                                label: 'VERIFIED',
                                isCompact: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: AppColors.champagneGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              chauffeur.rating.toStringAsFixed(1),
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              ' • ${chauffeur.totalTrips} Ceremonies',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${chauffeur.weddingExperienceYears} yrs wedding experience • Safa & Formal Attire',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondaryLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ceremonial Etiquette & Police Verified',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.verifiedEmerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View Profile',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.warmGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.warmGold,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const ShadiCard(
        padding: EdgeInsets.all(20),
        child: ShadiLoadingIndicator(size: 24),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
