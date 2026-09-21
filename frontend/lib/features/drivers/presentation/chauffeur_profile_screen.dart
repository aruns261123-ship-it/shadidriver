import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_verification_badge.dart';
import 'controllers/chauffeur_profile_controller.dart';

class ChauffeurProfileScreen extends ConsumerWidget {
  final String chauffeurId;

  const ChauffeurProfileScreen({super.key, required this.chauffeurId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chauffeurAsync = ref.watch(chauffeurProfileProvider(chauffeurId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Chauffeur Profile',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
          ),
        ),
      ),
      body: chauffeurAsync.when(
        data: (chauffeur) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              ShadiCard(
                padding: const EdgeInsets.all(20),
                border: Border.all(
                  color: AppColors.champagneGold.withValues(alpha: 0.4),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.secondarySurface,
                      child: const Icon(
                        Icons.person_rounded,
                        size: 48,
                        color: AppColors.primaryBurgundy,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      chauffeur.fullName,
                      style: AppTypography.displaySmall.copyWith(
                        color: AppColors.primaryBurgundy,
                        fontSize: 22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    if (chauffeur.verificationStatus == 'VERIFIED')
                      const ShadiVerificationBadge(
                        label: 'POLICE & IDENTITY VERIFIED',
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.champagneGold,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          chauffeur.rating.toStringAsFixed(1),
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${chauffeur.totalTrips} Ceremonies Completed)',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Key Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      label: 'Total Experience',
                      value: '${chauffeur.experienceYears} Years',
                      icon: Icons.badge_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      label: 'Wedding Specialization',
                      value: '${chauffeur.weddingExperienceYears} Years',
                      icon: Icons.celebration_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Operating Area & Languages
              const ShadiSectionHeader(
                title: 'Operating Info',
                subtitle: 'Service coverage and languages spoken',
              ),
              const SizedBox(height: 12),
              ShadiCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.map_rounded,
                      title: 'Coverage Area',
                      value: chauffeur.operatingArea,
                    ),
                    if (chauffeur.languages.isNotEmpty) ...[
                      const Divider(height: 24, color: AppColors.borderLight),
                      _buildInfoRow(
                        icon: Icons.translate_rounded,
                        title: 'Languages Spoken',
                        value: chauffeur.languages.join(', '),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bio / Etiquette Description
              if (chauffeur.bio.isNotEmpty) ...[
                const ShadiSectionHeader(
                  title: 'Ceremonial Bio & Protocol',
                  subtitle: 'Background and wedding service standards',
                ),
                const SizedBox(height: 12),
                ShadiCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    chauffeur.bio,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Verified Credentials Badges
              const ShadiSectionHeader(
                title: 'Verified Badges',
                subtitle: 'Quality and trust assurances',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildBadgePill(
                    icon: Icons.shield_outlined,
                    label: 'Police Verification',
                  ),
                  _buildBadgePill(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Background Checked',
                  ),
                  _buildBadgePill(
                    icon: Icons.dry_cleaning_outlined,
                    label: 'Royal Safa & Attire Trained',
                  ),
                  _buildBadgePill(
                    icon: Icons.access_time_rounded,
                    label: 'Punctuality Guarantee',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Reviews Section
              if (chauffeur.recentReviews.isNotEmpty) ...[
                ShadiSectionHeader(
                  title: 'Recent Reviews (${chauffeur.recentReviews.length})',
                  subtitle: 'Feedback from families and couples',
                ),
                const SizedBox(height: 12),
                ...chauffeur.recentReviews.map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShadiCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review.reviewerName,
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.primaryBurgundy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 16,
                                    color: AppColors.champagneGold,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    review.rating.toStringAsFixed(1),
                                    style: AppTypography.labelSmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review.comment,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        loading: () => const ShadiLoadingIndicator(
          message: 'Loading chauffeur credentials...',
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Chauffeur details could not be found.',
          onRetry: () => ref.refresh(chauffeurProfileProvider(chauffeurId)),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return ShadiCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.secondarySurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.warmGold),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiaryLight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.warmGold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadgePill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warmGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.warmGold),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
