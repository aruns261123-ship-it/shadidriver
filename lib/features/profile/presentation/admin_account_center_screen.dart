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
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Update Contact Info',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadiTextField(label: 'Full Name', controller: nameCtrl),
            const SizedBox(height: 12),
            ShadiTextField(label: 'Mobile Number', controller: phoneCtrl),
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
            ),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                await controller.updateContactInfo(
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.primaryBurgundy,
            ),
            tooltip: 'Return to Customer View',
            onPressed: () => context.go(RoutePaths.customerHome),
          ),
        ],
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
                        onTap: () {},
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
                        onTap: () {},
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
                        onTap: () => context.go(RoutePaths.customerHome),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
