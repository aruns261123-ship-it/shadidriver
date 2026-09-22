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
import '../../../core/widgets/shadi_text_field.dart';
import 'controllers/admin_profile_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Administrator Account & Profile Center Screen.
///
/// Invariant: Role and authorization levels are strictly read-only and immutable.
class AdminAccountCenterScreen extends ConsumerWidget {
  final String adminId;

  const AdminAccountCenterScreen({super.key, this.adminId = 'admin_ops'});

  void _showEditContactDialog(
    BuildContext context,
    AdminProfileController controller,
    String currentName,
    String currentPhone,
  ) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Contact Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadiTextField(
              controller: nameController,
              label: 'Full Name',
              hint: 'Enter full name',
            ),
            const SizedBox(height: 16),
            ShadiTextField(
              controller: phoneController,
              label: 'Phone Number',
              hint: '+91 98765 XXXXX',
              keyboardType: TextInputType.phone,
            ),
          ],
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
            onPressed: () {
              controller.updateContactInfo(
                fullName: nameController.text.trim(),
                phone: phoneController.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProfileControllerProvider(adminId));
    final controller = ref.read(
      adminProfileControllerProvider(adminId).notifier,
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Admin Profile & Security',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: ShadiLoadingIndicator(
                message: 'Loading admin credentials...',
              ),
            )
          : state.profile == null
          ? ShadiErrorView(
              message:
                  state.errorMessage ??
                  'Unable to load administrator credentials.',
              onRetry: () => controller.loadProfile(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Admin Header Card
                ShadiCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ShadiAvatarPicker(
                            photoUrl: state.profile!.photoUrl,
                            name: state.profile!.fullName,
                            size: 80,
                            isSaving: state.isSaving,
                            onPickFromGallery: () =>
                                controller.pickAndSavePhotoFromGallery(),
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
                                        state.profile!.fullName,
                                        style: AppTypography.titleLarge
                                            .copyWith(
                                              color: AppColors.primaryBurgundy,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    ShadiStatusBadge(
                                      status: state.profile!.role.displayLabel
                                          .toUpperCase(),
                                      color: AppColors.primaryBurgundy,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.profile!.email,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                Text(
                                  state.profile!.department,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.warmGold,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.borderLight),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Phone: ${state.profile!.phone}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showEditContactDialog(
                              context,
                              controller,
                              state.profile!.fullName,
                              state.profile!.phone,
                            ),
                            icon: const Icon(
                              Icons.edit_rounded,
                              size: 16,
                              color: AppColors.primaryBurgundy,
                            ),
                            label: Text(
                              'Edit Contact',
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
                ),

                const SizedBox(height: 16),

                // 2. Read-Only Authorization Invariant Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.security_rounded,
                            color: AppColors.warmGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Operational Authorization Level',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.profile!.authorizationLevel,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: AppColors.textSecondaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Administrative roles and authorization boundaries are managed exclusively by Super Admin provision and cannot be modified via profile UI.',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Security & Operational Sessions
                ShadiCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.devices_rounded,
                          color: AppColors.primaryBurgundy,
                        ),
                        title: const Text('Active Staff Sessions'),
                        subtitle: const Text('1 Active Android Device Console'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showActiveSessionsSheet(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.borderLight,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.policy_rounded,
                          color: AppColors.primaryBurgundy,
                        ),
                        title: const Text('Audit Trail & Compliance Logs'),
                        subtitle: const Text(
                          'View operations tamper-evident records',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showAuditTrailSheet(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.borderLight,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.primaryBurgundy,
                        ),
                        title: const Text('System & Security Help Desk'),
                        subtitle: const Text(
                          '24/7 technical incident and protocol response',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showSystemHelpSheet(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 60,
                        color: AppColors.borderLight,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.errorRed,
                        ),
                        title: Text(
                          'Sign Out of Operations Console',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Lock control room and end administrative session',
                        ),
                        onTap: () => _showAdminSignOutDialog(context, ref),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  void _showActiveSessionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Staff Sessions',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Hardware consoles currently authenticated with administrative clearance.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildAdminInfoRow(
                Icons.phone_android_rounded,
                'Primary Android Console (Active Now)',
                'Delhi NCR Hub • IP: 10.0.1.42 • Session: adm_ops_dlh_01',
              ),
              const SizedBox(height: 14),
              _buildAdminInfoRow(
                Icons.computer_rounded,
                'Desktop Operations Dashboard',
                'Last active 2 hours ago • New Delhi HQ',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditTrailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit Trail & Compliance Logs',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Tamper-evident operations log recording dispatch and KYC actions.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildAdminInfoRow(
                Icons.verified_user_rounded,
                'Chauffeur PB-01 Approved',
                'Identity & Police verification confirmed • Today 11:30 AM',
              ),
              const SizedBox(height: 14),
              _buildAdminInfoRow(
                Icons.directions_car_rounded,
                'Fleet BMW 5 Series Dispatched',
                'Assigned to ceremonial booking SD-2026-0100',
              ),
              const SizedBox(height: 14),
              _buildAdminInfoRow(
                Icons.security_rounded,
                'DPDP Consent Policy Verified',
                'Customer contact numbers masked for chauffeur privacy',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSystemHelpSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'System & Security Help Desk',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '24/7 technical incident response and IT infrastructure support.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildAdminInfoRow(
                Icons.phone_in_talk_rounded,
                'Operations Security Line (24/7)',
                '+91 1800-SHADI-SEC (1800-742-3473)',
              ),
              const SizedBox(height: 14),
              _buildAdminInfoRow(
                Icons.mark_email_read_rounded,
                'Cyber & Fraud Incident Desk',
                'security-ops@shadidriver.com',
              ),
              const SizedBox(height: 14),
              _buildAdminInfoRow(
                Icons.cloud_done_rounded,
                'Infrastructure Status',
                'All dispatch services operational • 99.99% uptime',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBurgundy, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAdminSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out of Operations Console'),
        content: const Text(
          'Are you sure you want to lock the control room and end your administrative session?',
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
