import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../bookings/domain/entities/booking_status.dart';
import '../../bookings/domain/entities/booking_submission_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import '../../drivers/domain/entities/chauffeur_kyc_application.dart';
import '../../drivers/presentation/controllers/chauffeur_kyc_controller.dart';
import 'controllers/admin_dashboard_controller.dart';

/// Admin Operations Control Center & Chauffeur KYC Hub.
///
/// All three tabs run on live data: dispatch rows and KPIs from the shared
/// booking + duty stores, the KYC queue from the verification repository
/// (approving flips the chauffeur's real verification status), and the Fleet
/// Registry from the vehicle store with engagement derived from live bookings.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operations Command Room',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primaryBurgundy,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Delhi NCR Hub • Live Dispatch & Fleet Operations',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_outlined,
              color: AppColors.primaryBurgundy,
            ),
            tooltip: 'Admin Profile & Security',
            onPressed: () => context.push(RoutePaths.adminProfile),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBurgundy,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primaryBurgundy,
          indicatorWeight: 3,
          labelStyle: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: AppTypography.labelMedium,
          tabs: const [
            Tab(text: 'Live Dispatch'),
            Tab(text: 'Chauffeur KYC'),
            Tab(text: 'Fleet Registry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveDispatchTab(),
          _buildKycQueueTab(),
          _buildFleetRegistryTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Live Dispatch Monitor (live booking + duty store data)
  // ---------------------------------------------------------------------------
  Widget _buildLiveDispatchTab() {
    final state = ref.watch(adminDashboardControllerProvider);

    return RefreshIndicator(
      color: AppColors.primaryBurgundy,
      onRefresh: () =>
          ref.read(adminDashboardControllerProvider.notifier).loadDashboard(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Stat Cards — computed from live duty + booking stores
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Live Ceremonies',
                  '${state.liveCeremoniesCount}',
                  Icons.celebration_rounded,
                  AppColors.primaryBurgundy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Chauffeurs On-Duty',
                  '${state.onDutyCount}',
                  Icons.person_pin_rounded,
                  AppColors.warmGold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  'Pending KYC',
                  '${ref.watch(chauffeurKycControllerProvider).pendingCount}',
                  Icons.badge_rounded,
                  Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Active Ceremonial Dispatch',
            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),

          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: ShadiLoadingIndicator(
                  message: 'Syncing dispatch monitor...',
                ),
              ),
            )
          else if (state.errorMessage != null)
            ShadiEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Dispatch Monitor Unavailable',
              description: state.errorMessage!,
              actionLabel: 'Retry',
              onAction: () => ref
                  .read(adminDashboardControllerProvider.notifier)
                  .loadDashboard(),
            )
          else if (state.dispatchEntries.isEmpty)
            const ShadiEmptyState(
              icon: Icons.celebration_outlined,
              title: 'No Active Dispatch',
              description:
                  'No ceremonies are currently in motion. New bookings and accepted assignments will appear here.',
            )
          else
            ...state.dispatchEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildDispatchRow(entry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return ShadiCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primaryBurgundy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchRow(AdminDispatchEntry entry) {
    final booking = entry.booking;
    final statusColor = switch (booking.status) {
      BookingStatus.requested => Colors.orange.shade700,
      BookingStatus.driverAccepted => Colors.blue.shade700,
      BookingStatus.driverAssigned => Colors.blue.shade700,
      BookingStatus.driverArriving => Colors.indigo.shade600,
      BookingStatus.arrived => Colors.purple.shade700,
      BookingStatus.tripStarted => AppColors.verifiedEmerald,
      BookingStatus.emergencyReplacement => Colors.red.shade600,
      _ => AppColors.warmGold,
    };
    final canForceDispatch = booking.status == BookingStatus.requested;

    return ShadiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.bookingReference,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBurgundy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.statusLabel,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.ceremonyType} • ${entry.vehicleName}',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Chauffeur: ${entry.chauffeurDisplayName}',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                size: 14,
                color: AppColors.warmGold,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.route,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Manual dispatch override (PRD: emergency SOS for unaccepted bookings)
          if (canForceDispatch) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('emergency_dispatch_${booking.bookingId}'),
                icon: Icon(Icons.emergency_rounded, size: 16),
                label: const Text('Emergency Standby Dispatch'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onPressed: () => _confirmEmergencyDispatch(context, booking),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Manual override confirmation + execution for the emergency standby flow.
  Future<void> _confirmEmergencyDispatch(
    BuildContext context,
    BookingSubmissionResult booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Emergency Standby Dispatch'),
        content: Text(
          'Force-dispatch the nearest AVAILABLE chauffeur to ${booking.bookingReference}? '
          'This bypasses the regular offer queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Dispatch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updated = await ref
        .read(adminDashboardControllerProvider.notifier)
        .dispatchEmergencyStandby(booking.bookingId);

    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          updated != null
              ? 'Standby chauffeur dispatched for ${updated.bookingReference}.'
              : 'Dispatch override failed — see the error banner.',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Chauffeur KYC & Verification Queue (repository-backed)
  // ---------------------------------------------------------------------------
  Widget _buildKycQueueTab() {
    final state = ref.watch(chauffeurKycControllerProvider);
    final controller = ref.read(chauffeurKycControllerProvider.notifier);

    if (state.isLoading) {
      return const Center(
        child: ShadiLoadingIndicator(message: 'Loading verification queue…'),
      );
    }

    if (state.errorMessage != null && state.applications.isEmpty) {
      return ShadiEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Queue Unavailable',
        description: state.errorMessage!,
        actionLabel: 'Retry',
        onAction: controller.loadApplications,
      );
    }

    if (state.applications.isEmpty) {
      return const ShadiEmptyState(
        icon: Icons.badge_outlined,
        title: 'No Applications',
        description: 'No chauffeur verification applications in the queue.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBurgundy,
      onRefresh: controller.loadApplications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.applications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final applicant = state.applications[index];
          final isPending = applicant.status == ChauffeurKycStatus.pending;
          final isActing =
              state.actingApplicationId == applicant.applicationId;

          final statusText = switch (applicant.status) {
            ChauffeurKycStatus.pending => 'PENDING',
            ChauffeurKycStatus.approved => 'APPROVED',
            ChauffeurKycStatus.rejected => 'REJECTED',
          };
          final statusColor = switch (applicant.status) {
            ChauffeurKycStatus.pending => Colors.orange,
            ChauffeurKycStatus.approved => AppColors.verifiedEmerald,
            ChauffeurKycStatus.rejected => Colors.red,
          };

          return ShadiCard(
            key: Key('kyc_card_${applicant.applicationId}'),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.secondarySurface,
                          child: Text(
                            applicant.fullName.substring(0, 1),
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              applicant.fullName,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              applicant.licenseNumber,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ShadiStatusBadge(
                      status: statusText,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.borderLight),
                const SizedBox(height: 10),

                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppColors.warmGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Police Clearance: ${applicant.policeClearanceStatus}',
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.check_box_outlined,
                      size: 14,
                      color: AppColors.warmGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ceremonial Attire: ${applicant.attireInspectionStatus}',
                        style: AppTypography.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.directions_car_outlined,
                      size: 14,
                      color: AppColors.warmGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Vehicle: ${applicant.vehicleAssigned}',
                        style: AppTypography.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (applicant.rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.block_rounded,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Rejected: ${applicant.rejectionReason}',
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Document review (Phase 2A: DL / RC / Insurance / Police NOC)
                _buildDocumentRow(context, controller, applicant),
                const SizedBox(height: 14),

                // Adjudication buttons
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: ShadiPrimaryButton(
                          key: Key('kyc_approve_${applicant.applicationId}'),
                          text: isActing ? 'Approving…' : 'Approve KYC',
                          isLoading: isActing,
                          onPressed: isActing
                              ? null
                              : () async {
                                  final ok = await controller.approve(
                                    applicant.applicationId,
                                  );
                                  if (ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Chauffeur ${applicant.fullName} verified for ceremonial duty.',
                                        ),
                                        backgroundColor:
                                            AppColors.verifiedEmerald,
                                      ),
                                    );
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ShadiSecondaryButton(
                          key: Key('kyc_reject_${applicant.applicationId}'),
                          text: 'Reject',
                          onPressed: isActing
                              ? null
                              : () => _showRejectSheet(
                                  context, controller, applicant),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Document row: shows each KYC document's upload state and opens the
  /// viewer/uploader sheet. Pending applications allow (re-)upload.
  Widget _buildDocumentRow(
    BuildContext context,
    ChauffeurKycController controller,
    ChauffeurKycApplication applicant,
  ) {
    final missing = KycDocumentType.values
        .where((t) => !applicant.documents.containsKey(t))
        .length;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showDocumentViewerSheet(context, controller, applicant),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.champagneGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.champagneGold),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.folder_shared_rounded,
              size: 18,
              color: AppColors.primaryBurgundy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${applicant.documents.length}/${KycDocumentType.values.length} verification documents uploaded',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              missing == 0
                  ? 'Complete'
                  : '$missing',
              style: AppTypography.labelSmall.copyWith(
                color: missing == 0
                    ? AppColors.verifiedEmerald
                    : Colors.orange.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }

  /// Admin document viewer: lists all four canonical KYC document types with
  /// their stored file reference; pending applications can upload/replace.
  void _showDocumentViewerSheet(
    BuildContext context,
    ChauffeurKycController controller,
    ChauffeurKycApplication applicant,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              Text(
                'Documents • ${applicant.fullName}',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Verification dossier — tap a missing document to attach a file reference.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 12),
              for (final type in KycDocumentType.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    applicant.documents.containsKey(type)
                        ? Icons.picture_as_pdf_rounded
                        : Icons.add_circle_outline_rounded,
                    color: applicant.documents.containsKey(type)
                        ? AppColors.verifiedEmerald
                        : AppColors.textSecondaryLight,
                    size: 22,
                  ),
                  title: Text(type.label),
                  subtitle: Text(
                    applicant.documents[type] ?? 'Not uploaded',
                    style: AppTypography.labelSmall.copyWith(
                      color: applicant.documents.containsKey(type)
                          ? AppColors.textSecondaryLight
                          : Colors.orange.shade800,
                    ),
                  ),
                  trailing: applicant.status == ChauffeurKycStatus.pending
                      ? const Icon(Icons.upload_rounded, size: 18)
                      : null,
                  onTap: applicant.status == ChauffeurKycStatus.pending
                      ? () async {
                          final ref = await _promptDocumentReference(
                            sheetContext,
                            type,
                          );
                          if (ref == null || !sheetContext.mounted) return;
                          final ok = await controller.uploadDocument(
                            applicationId: applicant.applicationId,
                            documentType: type,
                            fileReference: ref,
                          );
                          if (ok && sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        }
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Simple text prompt standing in for the device file picker (demo mock —
  /// the real backend will open a secure upload dialog).
  Future<String?> _promptDocumentReference(
    BuildContext sheetContext,
    KycDocumentType type,
  ) async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('Attach ${type.label}'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. dl_rajesh_2026.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              textController.text.trim().isEmpty
                  ? null
                  : textController.text.trim(),
            ),
            child: const Text('Attach'),
          ),
        ],
      ),
    );
  }

  void _showRejectSheet(
    BuildContext context,
    ChauffeurKycController controller,
    ChauffeurKycApplication applicant,
  ) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject Verification — ${applicant.fullName}',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBurgundy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The applicant will be notified with this reason. '
                'Rejection flips their verification status.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('kyc_reject_reason_field'),
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Operational reason (required)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ShadiPrimaryButton(
                  key: const Key('kyc_reject_confirm'),
                  text: 'Confirm Rejection',
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) return;
                    Navigator.pop(sheetContext);
                    await controller.reject(
                      applicant.applicationId,
                      reason: reason,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Fleet & Luxury Vehicle Registry (live vehicle store + engagements)
  // ---------------------------------------------------------------------------
  Widget _buildFleetRegistryTab() {
    final state = ref.watch(adminDashboardControllerProvider);

    if (state.fleetEntries.isEmpty && state.isLoading) {
      return const Center(
        child: ShadiLoadingIndicator(message: 'Loading fleet registry…'),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBurgundy,
      onRefresh: () =>
          ref.read(adminDashboardControllerProvider.notifier).loadDashboard(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: state.fleetEntries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final car = state.fleetEntries[index];
          final statusColor = car.isEngaged
              ? Colors.blue.shade700
              : (car.vehicle.isAvailableNow
                  ? AppColors.verifiedEmerald
                  : AppColors.textSecondaryLight);

          return ShadiCard(
            key: Key('fleet_card_${car.vehicle.id}'),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    car.isEngaged
                        ? Icons.celebration_rounded
                        : Icons.directions_car_filled_rounded,
                    color: AppColors.primaryBurgundy,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.displayName,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${car.registrationNumber} • ${car.vehicleClass}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    car.statusLabel,
                    style: AppTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
