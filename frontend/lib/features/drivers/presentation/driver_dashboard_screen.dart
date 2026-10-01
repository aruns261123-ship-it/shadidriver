import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/shadi_imagery.dart';
import '../../../core/theme/shadi_tokens.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_empty_state.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_offline_banner.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_ref_typography.dart';
import '../../../core/widgets/shadi_section_header.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import '../../partner/domain/entities/partner_enums.dart';
import '../../partner/domain/entities/partner_vehicle.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/providers/partner_providers.dart';
import '../../../core/widgets/shadi_logo_mark.dart';
import '../domain/entities/driver_active_trip.dart';
import '../domain/entities/driver_booking_offer.dart';
import '../domain/entities/driver_duty_status.dart';
import 'controllers/completed_assignments_controller.dart';
import 'controllers/driver_dashboard_controller.dart';
import 'controllers/driver_profile_controller.dart';

/// Live fleet preview for the Fleet Home header/metrics — the partner's real
/// `GET /partner/vehicles` payload, read-only on this screen. Mock mode (and
/// any fleet-fetch failure) degrades to an empty fleet rather than hanging
/// or throwing: the metrics simply show zeros.
final Provider<Future<PartnerFleet>> _fleetPreviewProvider =
    Provider<Future<PartnerFleet>>((ref) {
  final env = ref.watch(environmentConfigProvider);
  if (env.useMockData) {
    return Future.value(const PartnerFleet(items: [], total: 0));
  }
  final repo = ref.watch(partnerRepositoryProvider);
  return repo.listFleet().then(
        (result) => result.fold(
          (_) => const PartnerFleet(items: [], total: 0),
          (fleet) => fleet,
        ),
      );
});

/// Milestone 5: Chauffeur Operational Dashboard.
///
/// Rendered as the reference design's Fleet Home (PAGE 03): a burgundy header
/// ("Good morning, `name`" / "Your fleet is ready to move."), the floating
/// fleet-count card, the AVAILABILITY/VERIFICATION metric pair, Fleet
/// attention, and Your cars — followed by the real duty controls, offers,
/// and earnings sections (all live-data features preserved verbatim).
class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  /// The reference Fleet Home header (PAGE 03): burgundy block with the
  /// wordmark + notification row, "Good morning, `name`", the editorial
  /// "Your fleet is ready to move." heading, and the floating ivory fleet
  /// count card overlapping the header's bottom edge.
  Widget _buildFleetHomeHeader(
    BuildContext context,
    String driverName,
    DriverDashboardState state,
    PartnerFleet? fleet,
  ) {
    final carCount = fleet?.items.length ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 325,
          width: double.infinity,
          color: AppColors.primaryBurgundy,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: ShadiWordmark(light: true, fontSize: 17, markSize: 32),
                    ),
                    IconButton(
                      key: const Key('driver_dashboard_active_trip_action'),
                      icon: const Icon(Icons.navigation_rounded, color: Colors.white),
                      tooltip: 'Active Trip Console',
                      onPressed: () => _openActiveTrip(context, state),
                    ),
                    IconButton(
                      key: const Key('driver_dashboard_biometric_lock_action'),
                      icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
                      tooltip: 'Biometric Duty Lock',
                      onPressed: () => _showBiometricSecuritySheet(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                      tooltip: 'Chauffeur Profile',
                      onPressed: () => context.push(RoutePaths.driverProfile),
                    ),
                  ],
                ),
                const SizedBox(height: 33),
                Text(
                  'Good morning, $driverName',
                  style: ShadiRefType.ui10.copyWith(
                    color: AppColors.softChampagne,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Your fleet is\n',
                    children: [
                      TextSpan(
                        text: 'ready to move.',
                        style: const TextStyle(
                          color: AppColors.warmGold,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: ShadiRefType.display34.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        // Floating fleet-count card (bottom: -28 in the reference).
        Positioned(
          left: 18,
          right: 18,
          bottom: -28,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x143B0910),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '$carCount',
                  style: ShadiRefType.numeral32.copyWith(
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'cars in your fleet',
                    style: ShadiRefType.ui10.copyWith(
                      color: ShadiColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: ShadiPrimaryButton(
                    text: 'Manage My Cars',
                    height: 37,
                    onPressed: () =>
                        context.push(RoutePaths.partnerOnboarding),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverDashboardControllerProvider);
    final controller = ref.read(driverDashboardControllerProvider.notifier);
    final completedState = ref.watch(completedAssignmentsControllerProvider);
    final driverId = ref.watch(currentDriverIdProvider);
    final profileState = ref.watch(driverProfileControllerProvider(driverId));
    final driverName = profileState.profile?.fullName ?? 'Rajesh Kumar';
    final fleetFuture = ref.watch(_fleetPreviewProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.loadDashboard();
          // Completed Assignments uses a separate autoDispose provider; pull-
          // to-refresh should also refresh it so the history stays current.
          await ref
              .read(completedAssignmentsControllerProvider.notifier)
              .loadCompleted();
        },
        color: AppColors.primaryBurgundy,
        child: FutureBuilder<PartnerFleet>(
          future: fleetFuture,
          builder: (context, fleetSnap) {
            final fleet = fleetSnap.data;
            final availableCount = fleet?.items
                    .where((v) => v.isAvailable && v.isBookable)
                    .length ??
                0;
            final verifiedCount = fleet?.verifiedCount ?? 0;
            final expiringCount = fleet?.items.fold<int>(
                  0,
                  (sum, v) =>
                      sum +
                      v.documents
                          .where(
                            (d) =>
                                d.expiresAt != null &&
                                d.expiresAt!.isBefore(
                                  DateTime.now()
                                      .add(const Duration(days: 30)),
                                ),
                          )
                          .length,
                ) ??
                0;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                // REFERENCE FLEET HOME HEADER — burgundy, editorial greeting.
                _buildFleetHomeHeader(context, driverName, state, fleet),

                const SizedBox(height: 40), // room for the floating count card

                // REFERENCE METRIC PAIR — AVAILABILITY / VERIFICATION.
                _buildMetricPair(availableCount, verifiedCount),

                // REFERENCE FLEET ATTENTION — expiring documents.
                if (expiringCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 0, 17, 0),
                    child: _buildFleetAttention(expiringCount),
                  ),

                // REFERENCE YOUR CARS — the fleet rows.
                if (fleet != null && fleet.items.isNotEmpty)
                  _buildYourCars(fleet.items),

                const SizedBox(height: 12),

                // LIVE OPERATIONS SECTIONS (preserved verbatim).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 0. Offline Resilience Status
                      const ShadiOfflineBanner(
                        message:
                            'Chauffeur Offline Resilience Active • Itineraries cached',
                      ),
                      const SizedBox(height: 8),

                      // 1. Duty Status Selector Card
                      _buildDutyStatusCard(context, state, controller),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

            // 2. Status Explanation Banner
            _buildStatusBanner(context, state.dutyStatus, controller),

            if (state.hasActiveAssignment) ...[
              const SizedBox(height: 16),
              _buildActiveTripCard(context, state.activeAssignment!),
            ],

            const SizedBox(height: 20),

            // 3. Section Header for Assigned Duties (operations allocates ALL
            //    work — there is no incoming marketplace queue).
            ShadiSectionHeader(
              title: 'Assigned Duties',
              subtitle: state.offers.isEmpty
                  ? 'Operations allocates your duties — they appear here.'
                  : '${state.offers.length} operations-assigned dut${state.offers.length == 1 ? 'y' : 'ies'}',
            ),

            const SizedBox(height: 12),

            // 4. Duty Cards or Empty / Inactive State
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: ShadiLoadingIndicator(
                    message: 'Refreshing assigned duties...',
                  ),
                ),
              )
            else if (!state.canReceiveOffers && state.offers.isEmpty)
              _buildInactiveDispatchCard(context, controller)
            else if (state.offers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: ShadiEmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'No Assigned Duties',
                  description:
                      'ShadiDriver operations allocates every booking. Duties assigned to you appear here with the itinerary and host contact.',
                  actionLabel: 'Refresh Duties',
                  onAction: () => controller.refreshOffers(),
                ),
              )
            else
              ...state.offers.map((offer) => _buildOfferCard(context, offer)),

            const SizedBox(height: 20),

            // 5. Completed Assignments History (+ earnings summary)
            ShadiSectionHeader(
              title: 'Completed Assignments',
              subtitle: completedState.assignments.isEmpty
                  ? 'No concluded ceremonial services yet'
                  : '${completedState.assignments.length} concluded ceremony assignment${completedState.assignments.length == 1 ? '' : 's'}',
            ),

            if (!completedState.isLoading &&
                completedState.assignments.isNotEmpty &&
                completedState.assignments
                    .any((a) => (a.estimatedTotalPaise ?? 0) > 0)) ...[
              const SizedBox(height: 12),
              _buildEarningsCard(
                DriverEarningsSummary.fromAssignments(
                  completedState.assignments,
                ),
              ),
            ],

            const SizedBox(height: 12),

            if (completedState.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: ShadiLoadingIndicator()),
              )
            else if (completedState.assignments.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ShadiEmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Nothing Completed Yet',
                  description:
                      'Ceremonial services you conclude will be recorded here as completed assignments with full trip history.',
                ),
              )
            else
              ...completedState.assignments.map(
                (trip) => _buildCompletedAssignmentCard(context, trip),
              ),

            const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openActiveTrip(BuildContext context, DriverDashboardState state) {
    if (state.hasActiveAssignment) {
      context.push(
        RoutePaths.driverActiveTripPath(state.activeAssignment!.bookingId),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active ceremonial assignment right now.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// The reference AVAILABILITY / VERIFICATION metric pair.
  Widget _buildMetricPair(int availableCount, int verifiedCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 24),
      child: Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'AVAILABILITY',
              value: '$availableCount',
              caption: 'Available',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricCard(
              label: 'VERIFICATION',
              value: '$verifiedCount',
              caption: 'Verified',
            ),
          ),
        ],
      ),
    );
  }

  /// The reference "Fleet attention" card (documents expiring soon).
  Widget _buildFleetAttention(int expiringCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShadiRadius.fleetCard),
        border: Border.all(color: ShadiColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ShadiColors.warningSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 18,
              color: ShadiColors.saffron,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$expiringCount documents expiring soon',
                  style: ShadiRefType.ui10.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Review insurance documents',
                  style: ShadiRefType.ui8.copyWith(color: ShadiColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: ShadiColors.muted,
          ),
        ],
      ),
    );
  }

  /// The reference "Your cars" list: photo, name, registration, verification
  /// + availability badges, chevron. Language rule: AVAILABLE / NOT AVAILABLE.
  Widget _buildYourCars(List<PartnerVehicle> cars) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your cars',
            style: ShadiRefType.heading20.copyWith(color: AppColors.darkBurgundy),
          ),
          const SizedBox(height: 14),
          for (final car in cars)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ShadiRadius.fleetCard),
                border: Border.all(color: ShadiColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 49,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: AppColors.secondarySurface,
                      image: DecorationImage(
                        image: AssetImage(ShadiImagery.forVehicle(
                          car.photoUrls.isEmpty ? null : car.photoUrls.first,
                          vehicleId: car.id,
                        )),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          car.displayName ?? car.fleetCode,
                          style: ShadiRefType.ui10.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          car.maskedRegistration,
                          style: ShadiRefType.ui8.copyWith(
                            color: ShadiColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Flexible(
                              child: _MiniStatusBadge(
                                label: ShadiRefType.caps(
                                  car.verificationStatus.wire,
                                ),
                                tone: switch (car.verificationStatus) {
                                  PartnerVerificationStatus.approved =>
                                    _BadgeTone.success,
                                  PartnerVerificationStatus.submitted ||
                                  PartnerVerificationStatus.underReview ||
                                  PartnerVerificationStatus.pendingSubmission ||
                                  PartnerVerificationStatus.actionRequired =>
                                    _BadgeTone.warning,
                                  _ => _BadgeTone.danger,
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _MiniStatusBadge(
                                label: car.isAvailable && car.isBookable
                                    ? 'AVAILABLE'
                                    : 'NOT AVAILABLE',
                                tone: car.isAvailable && car.isBookable
                                    ? _BadgeTone.success
                                    : _BadgeTone.neutral,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ShadiColors.muted,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTripCard(BuildContext context, DriverActiveTrip trip) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.navigation_rounded,
                    color: AppColors.warmGold,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Assignment',
                    style: AppTypography.titleSmall.copyWith(
                      color: AppColors.primaryBurgundy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trip.bookingReference,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${trip.ceremonyType} Ceremony • ${trip.vehicleName} • ${trip.pickupAddress}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ShadiPrimaryButton(
              text: 'Open Trip Console',
              onPressed: () =>
                  context.push(RoutePaths.driverActiveTripPath(trip.bookingId)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyStatusCard(
    BuildContext context,
    DriverDashboardState state,
    DriverDashboardController controller,
  ) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Operational Duty Status',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBurgundy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ShadiStatusBadge(
                status: state.dutyStatus.code,
                color: _getStatusColor(state.dutyStatus),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DriverDutyStatus.values.map((status) {
              final isSelected = state.dutyStatus == status;
              return ChoiceChip(
                key: Key('duty_chip_${status.code}'),
                label: Text(status.displayLabel),
                selected: isSelected,
                selectedColor: AppColors.primaryBurgundy,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryBurgundy
                      : AppColors.borderLight,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
                onSelected: (selected) {
                  if (selected) {
                    controller.setDutyStatus(status);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    DriverDutyStatus dutyStatus,
    DriverDashboardController controller,
  ) {
    final (icon, text, color, showQuickAction) = switch (dutyStatus) {
      DriverDutyStatus.available => (
        Icons.check_circle_rounded,
        'Active Chauffeur Pool: Ready to receive ceremonial procession reservations.',
        AppColors.verifiedEmerald,
        false,
      ),
      DriverDutyStatus.availableNow => (
        Icons.bolt_rounded,
        'Immediate Dispatch Mode: Prioritized for urgent and upcoming ceremonial assignments.',
        AppColors.warmGold,
        false,
      ),
      DriverDutyStatus.busy => (
        Icons.access_time_rounded,
        'Chauffeur Busy: Currently assigned to an active ceremony. Dispatch offers paused.',
        Colors.orange,
        true,
      ),
      DriverDutyStatus.offline => (
        Icons.power_settings_new_rounded,
        'Chauffeur Offline: Switch status to Available to receive high-tier wedding offers.',
        Colors.grey.shade600,
        true,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showQuickAction)
            TextButton(
              onPressed: () =>
                  controller.setDutyStatus(DriverDutyStatus.available),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Go Available',
                style: TextStyle(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInactiveDispatchCard(
    BuildContext context,
    DriverDashboardController controller,
  ) {
    return ShadiCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(height: 12),
            const Text(
              'Duty List Paused',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'No duties to show right now. Switch to Available so operations can keep allocating work to you. Duties already assigned remain visible above.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  controller.setDutyStatus(DriverDutyStatus.available),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBurgundy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Switch to Available'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, DriverBookingOffer offer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ShadiCard(
        key: Key('driver_offer_card_${offer.bookingId}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Reference, Ceremony & Status. The chips group is
            // Flexible so a wide reference/status pair can never push the
            // row past the card edge at a narrow phone width.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondarySurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.champagneGold),
                          ),
                          child: Text(
                            offer.bookingReference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBurgundy,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBurgundy.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.ceremonyType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ShadiStatusBadge(
                  status: offer.statusLabel,
                  color: AppColors.warmGold,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Vehicle & Itinerary details
            Text(
              offer.vehicleName,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.warmGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormatter.formatCeremonyDate(offer.startDateTime)} • ${offer.durationHours} hrs duration',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Route Preview
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.primaryBurgundy,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${offer.pickupCity}: ${offer.pickupAddress}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Bottom row: Payout + Action Button. Earnings are only shown
            // when the server actually priced the row (duty views carry no
            // pricing — operations reports payouts separately).
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (offer.estimatedTotalPaise > 0) ...[
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Est. Chauffeur Earnings',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondaryLight,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          offer.formattedDriverEarningsPaise,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primaryBurgundy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  key: Key('review_offer_button_${offer.bookingId}'),
                  onPressed: () {
                    context.go(
                      RoutePaths.driverRequestDetailsPath(offer.bookingId),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('View Duty'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBurgundy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// History card for a concluded ceremonial assignment.
  /// Payout summary over concluded ceremonies (70% chauffeur share).
  Widget _buildEarningsCard(DriverEarningsSummary earnings) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.champagneGold.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primaryBurgundy,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Earnings (Concluded Ceremonies)',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _earningsStat(
                  'Net Payout (70%)',
                  earnings.netPayoutFormatted,
                ),
              ),
              Expanded(
                child: _earningsStat(
                  'Gross Bookings',
                  '₹${earnings.grossRupees.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _earningsStat(
                  'Hours on Duty',
                  '${earnings.hoursOnDuty} h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earningsStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedAssignmentCard(
    BuildContext context,
    DriverActiveTrip trip,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ShadiCard(
        key: Key('completed_assignment_card_${trip.bookingId}'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondarySurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.champagneGold),
                      ),
                      child: Text(
                        trip.bookingReference,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBurgundy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBurgundy.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trip.ceremonyType,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const ShadiStatusBadge(
                  status: 'COMPLETED',
                  color: AppColors.verifiedEmerald,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              '${trip.ceremonyType} Ceremony • ${trip.vehicleName}',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.warmGold,
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormatter.formatCeremonyDate(trip.serviceStartDateTime)} • ${trip.durationHours} hrs duration',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.primaryBurgundy,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip.pickupAddress,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (trip.tripCompletedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: AppColors.verifiedEmerald,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Concluded ${DateFormatter.formatCeremonyDateTime(trip.tripCompletedAt!)}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.verifiedEmerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(DriverDutyStatus status) {
    return switch (status) {
      DriverDutyStatus.available => AppColors.verifiedEmerald,
      DriverDutyStatus.availableNow => AppColors.warmGold,
      DriverDutyStatus.busy => Colors.orange,
      DriverDutyStatus.offline => Colors.grey,
    };
  }

  void _showBiometricSecuritySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: const BoxDecoration(
            color: Color(0xFF1B0B0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '✓ Identity Verified • Duty Console Active',
                      ),
                      backgroundColor: AppColors.verifiedEmerald,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(44),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.champagneGold,
                      width: 2,
                    ),
                    color: AppColors.champagneGold.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagneGold.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fingerprint_rounded,
                      size: 48,
                      color: AppColors.champagneGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Chauffeur Duty Security',
                style: AppTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Touch sensor or scan Face ID to verify identity and resume duty console.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Reference metric card (AVAILABILITY / VERIFICATION): hairline border,
/// tiny tracked label, Playfair numeral, small caption.
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ShadiRadius.fleetCard),
        border: Border.all(color: ShadiColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ShadiRefType.ui7.copyWith(
              color: ShadiColors.muted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: ShadiRefType.numeral27.copyWith(
              color: AppColors.primaryBurgundy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: ShadiRefType.ui10.copyWith(color: AppColors.textPrimaryLight),
          ),
        ],
      ),
    );
  }
}

enum _BadgeTone { success, warning, danger, neutral }

/// The reference fleet-row mini badge (19px, 6px text).
class _MiniStatusBadge extends StatelessWidget {
  final String label;
  final _BadgeTone tone;

  const _MiniStatusBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _BadgeTone.success => (ShadiColors.greenSoft, ShadiColors.green),
      _BadgeTone.warning => (ShadiColors.warningSoft, ShadiColors.saffron),
      _BadgeTone.danger => (ShadiColors.dangerSoft, ShadiColors.danger),
      _BadgeTone.neutral => (
          ShadiColors.neutralBadgeBg,
          ShadiColors.neutralBadgeFg,
        ),
    };
    return Container(
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ShadiRadius.badgePill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ShadiRefType.ui7.copyWith(
          fontSize: 6,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
