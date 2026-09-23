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
import 'controllers/driver_dashboard_controller.dart';
import '../domain/entities/driver_profile.dart';
import '../domain/entities/driver_duty_status.dart';
import '../../auth/presentation/controllers/auth_controller.dart';

/// Chauffeur Account & Profile Center Screen.
///
/// Features chauffeur bio, calculated profile completion percentage,
/// decoupled verification status badge, assigned fleet specs, and operational settings.
class DriverAccountCenterScreen extends ConsumerWidget {
  /// Explicit driver ID override. When null (the default), the screen reads
  /// the authenticated identity from [currentDriverIdProvider] — real mode
  /// uses the JWT user ID; mock mode resolves the demo roster key.
  final String? driverId;

  const DriverAccountCenterScreen({super.key, this.driverId});

  /// Resolves the badge label/color from live duty status, falling back to the
  /// static profile flag while loading or on error.
  ///
  /// [profile] may be null while the profile is still loading.
  (String, Color) _resolveDutyBadge(
    DriverProfile? profile,
    AsyncValue<DriverDutyStatus> dutyAsync,
  ) {
    final isOnlineFallback = profile?.isOnline ?? true;
    return dutyAsync.when(
      data: (duty) => switch (duty) {
        DriverDutyStatus.available => ('AVAILABLE', AppColors.verifiedEmerald),
        DriverDutyStatus.availableNow => ('AVAILABLE NOW', AppColors.warmGold),
        DriverDutyStatus.busy => ('BUSY', Colors.orange),
        DriverDutyStatus.offline => ('OFFLINE', AppColors.textSecondaryLight),
      },
      loading: () => (
        isOnlineFallback ? 'ON DUTY' : 'OFFLINE',
        isOnlineFallback
            ? AppColors.verifiedEmerald
            : AppColors.textSecondaryLight,
      ),
      error: (_, _) => (
        isOnlineFallback ? 'ON DUTY' : 'OFFLINE',
        isOnlineFallback
            ? AppColors.verifiedEmerald
            : AppColors.textSecondaryLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String effectiveDriverId =
        driverId ?? ref.watch(currentDriverIdProvider);
    final state = ref.watch(driverProfileControllerProvider(effectiveDriverId));
    final controller = ref.read(
      driverProfileControllerProvider(effectiveDriverId).notifier,
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
                _buildHeaderCard(context, ref, state, controller),

                const SizedBox(height: 16),

                // 2. Profile Completion Card (Decoupled from verification!)
                _buildCompletionCard(state.profile!),

                const SizedBox(height: 16),

                // 3. Verification & Compliance Card (Separate State!)
                _buildVerificationCard(
                  context,
                  state.profile!.verificationStatus,
                ),

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
                    onTap: () =>
                        _showAssignedVehicleSheet(context, state.profile!),
                  ),
                  _MenuItem(
                    icon: Icons.badge_rounded,
                    title: 'Chauffeur Documents',
                    subtitle:
                        '${state.profile!.documentStatus} • Commercial Badge & License',
                    onTap: () => _showKycComplianceSheet(
                      context,
                      state.profile!.verificationStatus == 'VERIFIED',
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.currency_rupee_rounded,
                    title: 'Payouts & Earnings',
                    subtitle:
                        'Direct deposit bank details and weekly earnings summary',
                    onTap: () => _showPayoutsSheet(context),
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
                    onTap: () => _showDispatchAlertsSheet(context),
                  ),
                  _MenuItem(
                    icon: Icons.security_rounded,
                    title: 'Chauffeur Code of Conduct',
                    subtitle: 'Royal ceremonial protocol & etiquette standards',
                    onTap: () => _showCodeOfConductSheet(context),
                  ),
                  _MenuItem(
                    icon: Icons.support_agent_rounded,
                    title: 'Chauffeur Support Desk',
                    subtitle:
                        'Direct emergency line to operations control room',
                    onTap: () => _showSupportDeskSheet(context),
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
    WidgetRef ref,
    DriverProfileState state,
    DriverProfileController controller,
  ) {
    final profile = state.profile!;
    // Live operational duty status (single source of truth: DriverRepository,
    // the same store the Chauffeur Console duty chips write to).
    final dutyAsync =
        ref.watch(driverDutyStatusProvider(driverId ?? ref.watch(currentDriverIdProvider)));
    final dutyBadge = _resolveDutyBadge(profile, dutyAsync);

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
                          status: dutyBadge.$1,
                          color: dutyBadge.$2,
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

  Widget _buildVerificationCard(
    BuildContext context,
    String verificationStatus,
  ) {
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
                const SizedBox(height: 10),
                InkWell(
                  key: const Key('driver_view_kyc_compliance_button'),
                  onTap: () => _showKycComplianceSheet(context, isVerified),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: AppColors.primaryBurgundy,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'View Verification Documents & Compliance',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showKycComplianceSheet(BuildContext context, bool isVerified) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
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
                    'Chauffeur KYC & Compliance',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Mandatory credentials audited by ShadiDriver Compliance before wedding assignments.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                'Commercial Driving License',
                'DL-04202100892 • Valid till 2031',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Vehicle RC (Commercial PSV)',
                'DL-01-AB-1234 • Luxury Sedan Permit',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Commercial Passenger Insurance',
                'Comprehensive ₹50L Coverage Active',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Police Background Clearance (NOC)',
                'Verified by Delhi Police Licensing Branch',
                isVerified,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Ceremonial Attire & Safa Inspection',
                'Royal Bandhgala & Gold Safa Standard Passed',
                isVerified,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceDocRow(String title, String subtitle, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.pending_rounded,
          color: passed ? AppColors.verifiedEmerald : AppColors.urgentSaffron,
          size: 20,
        ),
        const SizedBox(width: 10),
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

  void _showAssignedVehicleSheet(BuildContext context, DriverProfile profile) {
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
                    'Assigned Ceremonial Vehicle',
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
                'Vehicle allocation and ceremonial inspection certificate for duty.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                'Vehicle Model',
                'BMW 5 Series (Luxury Ceremonial Sedan)',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Fleet Plate & Permit',
                'DL-01-AB-1920 • Delhi NCR Commercial PSV',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Hygiene & White Glove Standard',
                'Sanitized & Floral Ribbon Mounting Verified',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Vehicle Fitness Status',
                '${profile.vehicleStatus} • Valid through 2026',
                true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayoutsSheet(BuildContext context) {
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
                    'Payouts & Bank Settlement',
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
                'Direct deposit bank details and weekly earnings distribution.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                'Settlement Account',
                'HDFC Bank ••••••1234 (Verified)',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Payout Cycle',
                'Weekly direct deposit every Monday 10:00 AM',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Muhurat Punctuality Bonus',
                'Eligible for ₹500 extra on every on-time arrival',
                true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showDispatchAlertsSheet(BuildContext context) {
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
                    'Dispatch & Alert Settings',
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
                'Urgent ceremony dispatch ringers, SMS, and departure timers.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                'High-Priority Ringer',
                'Audible loud chime on incoming ceremonial requests',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'SMS Backup Notification',
                'Fallback SMS alert with venue GPS pin link',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Muhurat Reminders',
                '60-minute & 30-minute departure chime before event start',
                true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCodeOfConductSheet(BuildContext context) {
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
                    'Chauffeur Code of Conduct',
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
                'Royal ceremonial protocol and white glove etiquette standards.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                '1. Royal Attire & Safa Discipline',
                'Mandatory ceremonial Bandhgala & Gold Safa turban',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                '2. Muhurat Punctuality',
                'Arrive at pickup gate exactly 30 minutes in advance',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                '3. Host & Bride Assistance',
                'Umbrella canopy & royal door greeting on every stop',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                '4. Absolute Privacy & Discretion',
                'Zero photography or discussion of VIP guests & gifts',
                true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSupportDeskSheet(BuildContext context) {
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
                    'Chauffeur Support Desk',
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
                'Direct lines to operations control room and emergency dispatch.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const Divider(height: 24),
              _buildComplianceDocRow(
                'Operations Room Hotline (24/7)',
                '+91 1800-SHADI-DRIVER (1800-742-3437)',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Emergency Standby Replacement',
                'Instant backup car dispatch in under 20 mins',
                true,
              ),
              const SizedBox(height: 12),
              _buildComplianceDocRow(
                'Compliance & Document Desk',
                'driver-support@shadidriver.com',
                true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
