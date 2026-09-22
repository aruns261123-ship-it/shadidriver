import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_avatar_picker.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import 'controllers/customer_profile_controller.dart';
import 'controllers/saved_addresses_controller.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Customer Account Center Screen.
///
/// Replaces the temporary placeholder in Tab 3 of the Customer navigation shell.
/// Features profile details, avatar management, saved addresses, booking history,
/// and luxury concierge settings.
class CustomerAccountCenterScreen extends ConsumerWidget {
  const CustomerAccountCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final profileState = ref.watch(
      customerProfileControllerProvider(session.userId),
    );
    final profileController = ref.read(
      customerProfileControllerProvider(session.userId).notifier,
    );
    final addressState = ref.watch(
      savedAddressesControllerProvider(session.userId),
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Account & Preferences',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: profileState.isLoading
          ? const Center(
              child: ShadiLoadingIndicator(
                message: 'Loading your royal profile...',
              ),
            )
          : profileState.profile == null
          ? ShadiErrorView(
              message: profileState.errorMessage ?? 'Unable to load profile.',
              onRetry: () => profileController.loadProfile(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Profile Header Card
                _buildProfileHeaderCard(
                  context,
                  profileState,
                  profileController,
                ),

                const SizedBox(height: 20),

                // 2. Ceremonial & Travel Section
                _buildSectionHeader('Ceremonial Travel & Bookings'),
                const SizedBox(height: 10),
                _buildMenuCard([
                  _MenuItem(
                    icon: Icons.pin_drop_rounded,
                    title: 'Saved Addresses',
                    subtitle:
                        '${addressState.addresses.length} saved addresses (Home, Venues)',
                    onTap: () => context.push(RoutePaths.customerAddresses),
                  ),
                  _MenuItem(
                    icon: Icons.calendar_today_rounded,
                    title: 'My Ceremonial Reservations',
                    subtitle: 'Review past and current wedding bookings',
                    onTap: () => context.go(RoutePaths.customerBookings),
                  ),
                  _MenuItem(
                    icon: Icons.favorite_rounded,
                    title: 'Shortlisted Fleet',
                    subtitle: 'Vehicles saved for your special occasions',
                    onTap: () => context.go(RoutePaths.customerSearch),
                  ),
                ]),

                const SizedBox(height: 20),

                // 3. Settings & Preferences
                _buildSectionHeader('Settings & Preferences'),
                const SizedBox(height: 10),
                _buildMenuCard([
                  _MenuItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'Notifications & Alerts',
                    subtitle: 'Booking updates and chauffeur dispatch SMS',
                    onTap: () => _showNotificationSheet(context),
                  ),
                  _MenuItem(
                    icon: Icons.security_rounded,
                    title: 'Privacy & Security',
                    subtitle: 'Manage data sharing and account credentials',
                    onTap: () => _showPrivacySheet(context),
                  ),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    title: '24/7 Royal Concierge Support',
                    subtitle: 'Raise a dispute or get help with a booking',
                    onTap: () => context.push(RoutePaths.customerSupportTicket),
                  ),
                ]),

                const SizedBox(height: 20),

                // 4. Account Actions
                _buildSectionHeader('Account Actions'),
                const SizedBox(height: 10),
                _buildMenuCard([
                  _MenuItem(
                    icon: Icons.edit_rounded,
                    title: 'Edit Royal Profile',
                    subtitle: 'Update full name, contact information, and city',
                    onTap: () => context.push(RoutePaths.customerProfileEdit),
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    title: 'Sign Out',
                    subtitle: 'End your current ceremonial session securely',
                    titleColor: AppColors.errorRed,
                    onTap: () => _showLogoutDialog(context, ref),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildProfileHeaderCard(
    BuildContext context,
    CustomerProfileState state,
    CustomerProfileController controller,
  ) {
    final profile = state.profile!;

    return ShadiCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              ShadiAvatarPicker(
                photoUrl: profile.profilePhotoUrl,
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
                        const ShadiStatusBadge(
                          status: 'CUSTOMER',
                          color: AppColors.warmGold,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: AppColors.warmGold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.city,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textPrimaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (profile.preferredLanguage != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${profile.preferredLanguage}',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
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
                'Member of Ceremonial Registry',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(RoutePaths.customerProfileEdit),
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
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.titleColor ?? AppColors.primaryBurgundy,
                    size: 22,
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

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to end your ceremonial session?',
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

  void _showNotificationSheet(BuildContext context) {
    bool smsAlerts = true;
    bool reminders = true;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Preferences',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: smsAlerts,
                  onChanged: (val) => setSheetState(() => smsAlerts = val),
                  activeTrackColor: AppColors.warmGold,
                  activeThumbColor: Colors.white,
                  title: const Text('Chauffeur Arrival SMS'),
                  subtitle: const Text(
                    'Real-time alerts when chauffeur reaches venue',
                  ),
                ),
                SwitchListTile(
                  value: reminders,
                  onChanged: (val) => setSheetState(() => reminders = val),
                  activeTrackColor: AppColors.warmGold,
                  activeThumbColor: Colors.white,
                  title: const Text('Baraat Schedule Reminders'),
                  subtitle: const Text(
                    'Advance notifications for wedding timelines',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy & Data Protection',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ShadiDriver enforces confidential, hardware-backed encryption for all customer itineraries and contact details. Chauffeurs receive contact information only during active reservations.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
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
