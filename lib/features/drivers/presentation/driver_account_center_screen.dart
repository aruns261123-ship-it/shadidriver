import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_avatar_picker.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import 'controllers/driver_profile_controller.dart';
import '../domain/entities/driver_profile.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Chauffeur Account & Profile Center Screen.
///
/// Features chauffeur bio, calculated profile completion percentage,
/// decoupled verification status badge, assigned fleet specs, and operational settings.
class DriverAccountCenterScreen extends ConsumerWidget {
  final String driverId;

  const DriverAccountCenterScreen({super.key, this.driverId = 'd1'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverProfileControllerProvider(driverId));
    final controller = ref.read(
      driverProfileControllerProvider(driverId).notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primaryBurgundy,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.driver),
        ),
        title: Text(
          'Chauffeur Profile',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: ShadiLoadingIndicator(
                message: 'Loading chauffeur profile...',
              ),
            )
          : state.profile == null
          ? ShadiErrorView(
              message:
                  state.errorMessage ?? 'Unable to load chauffeur profile.',
              onRetry: () => controller.loadProfile(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Chauffeur Header
                _buildHeaderCard(context, state, controller),

                const SizedBox(height: 16),

                // 2. Profile Completion Card (Decoupled from verification!)
                _buildCompletionCard(state.profile!),

                const SizedBox(height: 16),

                // 3. Verification & Compliance Card (Separate State!)
                _buildVerificationCard(state.profile!.verificationStatus),

                const SizedBox(height: 20),

                // 4. Fleet & Operational Overview
                _buildSectionHeader('Fleet & Duty Credentials'),
                const SizedBox(height: 10),
                _buildMenuCard([
                  _MenuItem(
                    icon: Icons.directions_car_rounded,
                    title: 'Assigned Vehicle',
                    subtitle:
                        '${state.profile!.vehicleStatus} • Inspected for Ceremonies',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.badge_rounded,
                    title: 'Chauffeur Documents',
                    subtitle:
                        '${state.profile!.documentStatus} • Commercial Badge & License',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.currency_rupee_rounded,
                    title: 'Payouts & Earnings',
                    subtitle:
                        'Direct deposit bank details and weekly earnings summary',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // 5. Account Actions
                _buildSectionHeader('Account & Operations'),
                const SizedBox(height: 10),
                _buildMenuCard([
                  _MenuItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'Dispatch Alerts',
                    subtitle: 'Urgent ceremony dispatch ringers and SMS',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.security_rounded,
                    title: 'Chauffeur Code of Conduct',
                    subtitle: 'Royal ceremonial protocol & etiquette standards',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Chauffeur Support Desk',
                    subtitle:
                        'Direct emergency line to operations control room',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out of Chauffeur Console',
                    subtitle: 'Go offline and end duty session securely',
                    titleColor: AppColors.errorRed,
                    onTap: () => _showDriverSignOutDialog(context, ref),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    DriverProfileState state,
    DriverProfileController controller,
  ) {
    final profile = state.profile!;

    return ShadiCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              ShadiAvatarPicker(
                photoUrl: profile.profileImageUrl,
                name: profile.fullName,
                size: 84,
                isSaving: state.isSaving,
                onPickFromGallery: () =>
                    controller.pickAndSavePhotoFromGallery(),
                onCaptureFromCamera: () =>
                    controller.captureAndSavePhotoFromCamera(),
                onRemovePhoto: () => controller.removePhoto(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.fullName,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ShadiStatusBadge(
                          status: profile.isOnline ? 'ON DUTY' : 'OFFLINE',
                          color: profile.isOnline
                              ? AppColors.verifiedEmerald
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const ShadiStatusBadge(
                          status: 'CHAUFFEUR',
                          color: AppColors.warmGold,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${profile.experienceYears} Yrs Total Exp • ${profile.weddingExperienceYears} Yrs Wedding Exp',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.operatingArea,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Languages: ${profile.languages.join(", ")}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.secondarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                profile.bio,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const Divider(height: 24, color: AppColors.borderLight),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppColors.warmGold,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${profile.rating} Rating (${profile.totalTrips} Ceremonies)',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(RoutePaths.driverProfileEdit),
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: AppColors.primaryBurgundy,
                ),
                label: Text(
                  'Edit Profile',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(DriverProfile profile) {
    final percentage = profile.completionPercentage;
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$percentage%',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.warmGold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 8,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.warmGold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (profile.isProfileComplete) ...[
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.verifiedEmerald,
                ),
                const SizedBox(width: 6),
                Text(
                  'Professional profile complete',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.verifiedEmerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Missing: ${profile.missingProfileItems.join(", ")}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationCard(String verificationStatus) {
    final isVerified = verificationStatus == 'VERIFIED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isVerified
            ? AppColors.verifiedEmerald.withValues(alpha: 0.08)
            : AppColors.urgentSaffron.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified
              ? AppColors.verifiedEmerald.withValues(alpha: 0.4)
              : AppColors.urgentSaffron.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isVerified
                ? Icons.verified_user_rounded
                : Icons.pending_actions_rounded,
            color: isVerified
                ? AppColors.verifiedEmerald
                : AppColors.urgentSaffron,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verification Status',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    ShadiStatusBadge(
                      status: verificationStatus,
                      color: isVerified
                          ? AppColors.verifiedEmerald
                          : AppColors.urgentSaffron,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Driver verification is conducted independently by ShadiDriver Compliance. Profile completeness does not bypass document verification.',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: AppTypography.titleSmall.copyWith(
          color: AppColors.primaryBurgundy,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<_MenuItem> items) {
    return ShadiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          final item = entry.value;

          return Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.titleColor ?? AppColors.primaryBurgundy,
                    size: 20,
                  ),
                ),
                title: Text(
                  item.title,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: item.titleColor ?? AppColors.textPrimaryLight,
                  ),
                ),
                subtitle: item.subtitle != null
                    ? Text(
                        item.subtitle!,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      )
                    : null,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryLight,
                  size: 20,
                ),
                onTap: item.onTap,
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  indent: 60,
                  color: AppColors.borderLight,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showDriverSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out of Chauffeur Console'),
        content: const Text(
          'Are you sure you want to go offline and end your chauffeur duty session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBurgundy,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(RoutePaths.auth);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });
}
