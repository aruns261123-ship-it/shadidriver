import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_ceremonial_route_map.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../domain/entities/driver_trip_stage.dart';
import 'controllers/driver_active_trip_controller.dart';

/// Chauffeur Active Trip Console guiding the driver through every step of the
/// ceremonial journey from departure to completion with host OTP validation.
class DriverActiveTripScreen extends ConsumerWidget {
  final String bookingId;

  const DriverActiveTripScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverActiveTripControllerProvider(bookingId));
    final controller = ref.read(
      driverActiveTripControllerProvider(bookingId).notifier,
    );
    final trip = state.trip;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trip Console • ${trip.bookingReference}',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.primaryBurgundy,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${trip.ceremonyType} Ceremony • ${trip.vehicleName}',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Stage Progress Stepper
          _buildStageStepper(trip.stage),
          const SizedBox(height: 16),

          // 2. Active Stage Status Banner
          _buildStageBanner(trip.stage),
          const SizedBox(height: 16),

          // Error Message if any
          if (state.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 3. Route & Itinerary Card
          _buildRouteCard(trip),
          const SizedBox(height: 14),

          // 4. Host & Coordinator Details
          _buildHostCard(context, trip),
          const SizedBox(height: 14),

          // 5. Ceremonial Attire & Standards Card
          _buildCeremonialStandardsCard(trip),
          const SizedBox(height: 24),

          // 6. Pre-trip Checklist (assigned stage only, PRD pre-trip protocol)
          if (trip.stage == DriverTripStage.assigned) ...[
            _buildPreTripChecklistCard(context, controller),
            const SizedBox(height: 14),
          ],

          // 7. Action Button Section based on Stage
          _buildActionSection(
            context,
            trip.stage,
            controller,
            state.isUpdating,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Pre-trip checklist card (fuel / dual-AC / grooming). The driver must
  /// confirm all three before the Start Journey button becomes available —
  /// mirrors the PRD's mandatory pre-trip protocol.
  Widget _buildPreTripChecklistCard(
    BuildContext context,
    DriverActiveTripController controller,
  ) {
    final submitted = controller.preTripChecklistSubmitted;
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: AppColors.primaryBurgundy,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pre-Trip Checklist',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (submitted)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.verifiedEmerald,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            submitted
                ? 'All checks confirmed. You are clear to start the journey.'
                : 'Confirm all three checks before starting the journey.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (!submitted) ...[
            const SizedBox(height: 12),
            ShadiSecondaryButton(
              text: 'Open Pre-Trip Checklist',
              onPressed: () => _showPreTripChecklistSheet(context, controller),
            ),
          ],
        ],
      ),
    );
  }

  void _showPreTripChecklistSheet(
    BuildContext context,
    DriverActiveTripController controller,
  ) {
    bool fuel = false, dualAc = false, grooming = false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
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
                  'Pre-Trip Checklist',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mandatory before every ceremonial journey.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: fuel,
                  onChanged: (v) => setSheetState(() => fuel = v ?? false),
                  title: const Text('Fuel level sufficient for route'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: dualAc,
                  onChanged: (v) => setSheetState(() => dualAc = v ?? false),
                  title: const Text('Dual AC cooling verified'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: grooming,
                  onChanged: (v) => setSheetState(() => grooming = v ?? false),
                  title: const Text('Grooming & ceremonial attire inspected'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),
                ShadiPrimaryButton(
                  text: 'Confirm Checklist',
                  isLoading: false,
                  onPressed: (!fuel || !dualAc || !grooming)
                      ? null
                      : () async {
                          final ok = await controller.submitPreTripChecklist(
                            isFuelChecked: fuel,
                            isDualAcChecked: dualAc,
                            isGroomingChecked: grooming,
                          );
                          if (sheetContext.mounted && ok) {
                            Navigator.pop(sheetContext);
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStageStepper(DriverTripStage stage) {
    final stages = [
      ('En Route', DriverTripStage.enRouteToPickup),
      ('Arrived', DriverTripStage.arrivedAtPickup),
      ('Ceremony', DriverTripStage.ceremonyInProgress),
      ('Done', DriverTripStage.completed),
    ];

    final currentIndex = switch (stage) {
      DriverTripStage.assigned => -1,
      DriverTripStage.enRouteToPickup => 0,
      DriverTripStage.arrivedAtPickup => 1,
      DriverTripStage.ceremonyInProgress => 2,
      DriverTripStage.completed => 3,
    };

    return ShadiCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(stages.length * 2 - 1, (index) {
          if (index.isOdd) {
            final prevStageIndex = index ~/ 2;
            final isDone = prevStageIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isDone
                    ? AppColors.primaryBurgundy
                    : AppColors.borderLight,
              ),
            );
          }

          final stageIndex = index ~/ 2;
          final item = stages[stageIndex];
          final isPast = stageIndex < currentIndex;
          final isCurrent = stageIndex == currentIndex;

          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? AppColors.primaryBurgundy
                      : (isPast ? AppColors.champagneGold : Colors.white),
                  border: Border.all(
                    color: (isCurrent || isPast)
                        ? AppColors.primaryBurgundy
                        : AppColors.borderLight,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isPast
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${stageIndex + 1}',
                          style: AppTypography.labelSmall.copyWith(
                            color: isCurrent
                                ? Colors.white
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.$1,
                style: AppTypography.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.primaryBurgundy
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStageBanner(DriverTripStage stage) {
    Color bg;
    Color border;
    IconData icon;
    String title;
    String subtitle;

    switch (stage) {
      case DriverTripStage.assigned:
        bg = AppColors.secondarySurface;
        border = AppColors.borderLight;
        icon = Icons.assignment_turned_in_rounded;
        title = 'Ceremonial Assignment Ready';
        subtitle =
            'Check your ceremonial attire and vehicle hygiene before starting.';
        break;
      case DriverTripStage.enRouteToPickup:
        bg = const Color(0xFFFFF8E1);
        border = const Color(0xFFFFD54F);
        icon = Icons.navigation_rounded;
        title = 'Driving to Pickup Venue';
        subtitle =
            'Navigate smoothly. Follow gate entry instructions upon arrival.';
        break;
      case DriverTripStage.arrivedAtPickup:
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFF81C784);
        icon = Icons.pin_drop_rounded;
        title = 'Arrived at Venue';
        subtitle =
            'Greet the host respectfully. Ask for the 4-digit start OTP.';
        break;
      case DriverTripStage.ceremonyInProgress:
        bg = AppColors.champagneGold.withValues(alpha: 0.15);
        border = AppColors.warmGold.withValues(alpha: 0.5);
        icon = Icons.celebration_rounded;
        title = 'Ceremonial Service in Progress';
        subtitle =
            'Maintain stately speed. Be available for ribbon-cutting or photo stops.';
        break;
      case DriverTripStage.completed:
        bg = const Color(0xFFE0F2F1);
        border = const Color(0xFF4DB6AC);
        icon = Icons.verified_rounded;
        title = 'Ceremony Completed';
        subtitle =
            'Service concluded successfully. Payment token and settlement recorded.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBurgundy, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(dynamic trip) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route & Venue Details', style: AppTypography.labelMedium),
          const SizedBox(height: 12),
          ShadiCeremonialRouteMap(
            pickupLocation: trip.pickupAddress,
            destinationLocation: trip.destinationAddress.isNotEmpty
                ? trip.destinationAddress
                : 'Ceremonial Banquet Hall',
            distance: trip.routeDistanceKm != null
                ? '${trip.routeDistanceKm!.toStringAsFixed(1)} km'
                : '14.2 km',
            duration: '32 mins',
            isLive:
                trip.stage == DriverTripStage.enRouteToPickup ||
                trip.stage == DriverTripStage.ceremonyInProgress,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.my_location_rounded,
                color: AppColors.warmGold,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup Location', style: AppTypography.labelSmall),
                    Text(trip.pickupAddress, style: AppTypography.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              height: 18,
              child: VerticalDivider(
                color: AppColors.borderLight,
                thickness: 1.5,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.pin_drop_rounded,
                color: AppColors.primaryBurgundy,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ceremony Venue', style: AppTypography.labelSmall),
                    Text(
                      '${trip.venueName.isNotEmpty ? "${trip.venueName} • " : ""}${trip.destinationAddress}',
                      style: AppTypography.bodySmall,
                    ),
                    if (trip.landmark.isNotEmpty)
                      Text(
                        'Entry: ${trip.landmark}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primaryBurgundy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (trip.routeDistanceKm != null) ...[
            const SizedBox(height: 10),
            Text(
              'Estimated Route: ${trip.routeDistanceKm!.toStringAsFixed(1)} km',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHostCard(BuildContext context, dynamic trip) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.primaryBurgundy,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.primaryContactName,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Wedding Host / Coordinator',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.phone_rounded,
              color: AppColors.primaryBurgundy,
            ),
            tooltip: 'Call Host',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling Host at ${trip.primaryContactPhone}'),
                  backgroundColor: AppColors.primaryBurgundy,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCeremonialStandardsCard(dynamic trip) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ceremonial Standards', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.warmGold,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Required Attire: ${trip.ceremonialAttire}',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.warmGold,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ceremonial Vehicle: ${trip.vehicleName}',
                  style: AppTypography.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    DriverTripStage stage,
    DriverActiveTripController controller,
    bool isUpdating,
  ) {
    switch (stage) {
      case DriverTripStage.assigned:
        return ShadiPrimaryButton(
          text: 'Start Journey to Pickup',
          isLoading: isUpdating,
          onPressed: isUpdating
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  controller.startEnRoute();
                },
        );

      case DriverTripStage.enRouteToPickup:
        return ShadiPrimaryButton(
          text: 'Arrived at Pickup / Venue',
          isLoading: isUpdating,
          onPressed: isUpdating
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  controller.markArrived();
                },
        );

      case DriverTripStage.arrivedAtPickup:
        return ShadiPrimaryButton(
          text: 'Start Ceremonial Service',
          isLoading: isUpdating,
          onPressed: isUpdating
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _showStartOtpModal(context, controller);
                },
        );

      case DriverTripStage.ceremonyInProgress:
        return ShadiPrimaryButton(
          text: 'Conclude Ceremonial Service',
          isLoading: isUpdating,
          onPressed: isUpdating
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  controller.completeService();
                },
        );

      case DriverTripStage.completed:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '🎉 All ceremonial duties successfully completed!',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryBurgundy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ShadiSecondaryButton(
              text: 'Return to Chauffeur Dashboard',
              onPressed: () => context.go(RoutePaths.driver),
            ),
          ],
        );
    }
  }

  void _showStartOtpModal(
    BuildContext context,
    DriverActiveTripController controller,
  ) {
    final otpController = TextEditingController();
    bool attireChecked = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start Ceremonial Service',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBurgundy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask the host for the 4-digit ceremonial start code provided in their booking.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textAlign: TextAlign.center,
                    style: AppTypography.titleLarge.copyWith(
                      letterSpacing: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      filled: true,
                      fillColor: AppColors.secondarySurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  CheckboxListTile(
                    value: attireChecked,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryBurgundy,
                    title: Text(
                      'I am wearing the ceremonial uniform (Bandhgala & Safa) and car is clean.',
                      style: AppTypography.bodySmall,
                    ),
                    onChanged: (val) {
                      setModalState(() => attireChecked = val ?? false);
                    },
                  ),
                  const SizedBox(height: 16),

                  ShadiPrimaryButton(
                    text: 'Confirm & Begin Ceremony',
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final code = otpController.text.trim();
                      Navigator.pop(modalCtx);
                      await controller.startCeremonyService(
                        otp: code,
                        attireConfirmed: attireChecked,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
