import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../domain/entities/driver_booking_offer.dart';
import '../domain/entities/driver_decline_reason.dart';
import 'controllers/driver_booking_action_controller.dart';
import 'controllers/driver_dashboard_controller.dart';

/// Milestone 5: Chauffeur Booking Request Details Screen.
///
/// Presents ceremonial itinerary details, masked customer PII (DPDP compliant),
/// net driver earnings, and explicit Accept / Decline actions with mandatory reason.
class DriverBookingRequestScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const DriverBookingRequestScreen({super.key, required this.bookingId});

  @override
  ConsumerState<DriverBookingRequestScreen> createState() =>
      _DriverBookingRequestScreenState();
}

class _DriverBookingRequestScreenState
    extends ConsumerState<DriverBookingRequestScreen> {
  @override
  Widget build(BuildContext context) {
    final offerAsync = ref.watch(
      driverBookingOfferDetailsProvider(widget.bookingId),
    );
    final actionState = ref.watch(driverBookingActionControllerProvider);

    // Listen to action state changes for navigation and dialogs
    ref.listen<DriverBookingActionState>(
      driverBookingActionControllerProvider,
      (previous, current) {
        if (current.isAccepted) {
          // Invalidate dashboard so offers update
          ref.invalidate(driverDashboardControllerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Offer Accepted! You are assigned as the ceremonial chauffeur.',
              ),
              backgroundColor: AppColors.verifiedEmerald,
            ),
          );
          _navigateToDashboard(context);
        } else if (current.isDeclined) {
          // Invalidate dashboard so declined offer is removed
          ref.invalidate(driverDashboardControllerProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer declined.'),
              duration: Duration(seconds: 2),
            ),
          );
          _navigateToDashboard(context);
        } else if (current.isConflict) {
          _showConflictDialog(
            context,
            current.errorMessage ??
                'This booking has already been accepted by another chauffeur.',
          );
        } else if (current.errorMessage != null && !current.isConflict) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(current.errorMessage!),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
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
          onPressed: () => _navigateToDashboard(context),
        ),
        title: Text(
          'Ceremonial Offer',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: offerAsync.when(
        loading: () => const Center(
          child: ShadiLoadingIndicator(
            message: 'Retrieving itinerary details...',
          ),
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Unable to load booking details: $err',
          onRetry: () =>
              ref.refresh(driverBookingOfferDetailsProvider(widget.bookingId)),
        ),
        data: (offer) => _buildBody(context, offer, actionState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    DriverBookingOffer offer,
    DriverBookingActionState actionState,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Earnings and Reference Hero Card
                _buildEarningsCard(offer),

                const SizedBox(height: 16),

                // 2. Customer & DPDP Privacy Card
                _buildPrivacyCard(offer),

                const SizedBox(height: 16),

                // 3. Ceremonial Itinerary Card
                _buildItineraryCard(offer),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        _buildBottomActionBar(context, offer, actionState),
      ],
    );
  }

  Widget _buildEarningsCard(DriverBookingOffer offer) {
    return ShadiCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.champagneGold),
                ),
                child: Text(
                  'Ref: ${offer.bookingReference}',
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warmGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'REQUESTED',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primaryBurgundy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Estimated Chauffeur Payout',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                offer.formattedDriverEarningsPaise,
                style: AppTypography.displayMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBurgundy,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'net ceremonial payout',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Includes 80% ceremonial base compensation. Tolls and ceremonial decor allowance accounted for at completion.',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(DriverBookingOffer offer) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: AppColors.verifiedEmerald,
              ),
              SizedBox(width: 8),
              Text('Host Identity & Privacy', style: AppTypography.titleSmall),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: AppColors.primaryBurgundy,
              ),
              const SizedBox(width: 10),
              Text(
                offer.maskedCustomerName,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.phone_outlined,
                size: 18,
                color: AppColors.primaryBurgundy,
              ),
              const SizedBox(width: 10),
              Text('Phone: ', style: AppTypography.labelMedium),
              Text(
                offer.maskedCustomerPhone,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.verifiedEmerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.verifiedEmerald.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.verifiedEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'DPDP Act 2023 Compliance: Host phone number and venue security passcodes are released immediately after offer acceptance.',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textPrimaryLight,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(DriverBookingOffer offer) {
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ceremonial Itinerary',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBurgundy,
            ),
          ),
          const Divider(height: 20),
          _buildInfoRow('Event Name', offer.eventName),
          const SizedBox(height: 10),
          _buildInfoRow('Ceremony', offer.ceremonyType),
          const SizedBox(height: 10),
          _buildInfoRow('Assigned Vehicle', offer.vehicleName),
          const SizedBox(height: 10),
          _buildInfoRow('Chauffeur Attire', offer.ceremonialAttire),
          const SizedBox(height: 10),
          _buildInfoRow(
            'Date & Schedule',
            '${DateFormatter.formatCeremonyDate(offer.startDateTime)} (${offer.durationHours} hrs)',
          ),
          const SizedBox(height: 10),
          _buildInfoRow('Pickup Venue', offer.pickupAddress),
          const SizedBox(height: 10),
          _buildInfoRow('Destination Venue', offer.dropoffAddress),
          if (offer.specialInstructions != null &&
              offer.specialInstructions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow('Special Protocol', offer.specialInstructions!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    DriverBookingOffer offer,
    DriverBookingActionState actionState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ShadiSecondaryButton(
                key: const Key('driver_decline_button'),
                text: 'Decline Offer',
                onPressed: actionState.isActing
                    ? null
                    : () => _showDeclineBottomSheet(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShadiPrimaryButton(
                key: const Key('driver_accept_button'),
                text: 'Accept Offer',
                isLoading: actionState.isActing,
                onPressed: actionState.isActing
                    ? null
                    : () {
                        ref
                            .read(
                              driverBookingActionControllerProvider.notifier,
                            )
                            .acceptOffer(widget.bookingId);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConflictDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Offer No Longer Available'),
          ],
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          ElevatedButton(
            key: const Key('conflict_dialog_ok_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBurgundy,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go(RoutePaths.driver);
            },
            child: const Text('Return to Console'),
          ),
        ],
      ),
    );
  }

  void _showDeclineBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _DeclineReasonBottomSheet(
        onConfirm: (reason) {
          Navigator.of(sheetContext).pop();
          ref
              .read(driverBookingActionControllerProvider.notifier)
              .declineOffer(widget.bookingId, reason);
        },
      ),
    );
  }

  void _navigateToDashboard(BuildContext context) {
    if (!context.mounted) return;
    try {
      context.go(RoutePaths.driver);
    } catch (_) {
      Navigator.of(context).maybePop();
    }
  }
}

/// Bottom sheet requiring a mandatory decline reason selection.
class _DeclineReasonBottomSheet extends StatefulWidget {
  final ValueChanged<DriverDeclineReason> onConfirm;

  const _DeclineReasonBottomSheet({required this.onConfirm});

  @override
  State<_DeclineReasonBottomSheet> createState() =>
      _DeclineReasonBottomSheetState();
}

class _DeclineReasonBottomSheetState extends State<_DeclineReasonBottomSheet> {
  DriverDeclineReason? _selectedReason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Decline Booking Offer',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A reason is mandatory to notify ceremonial dispatch and reassign this itinerary.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            RadioGroup<DriverDeclineReason>(
              groupValue: _selectedReason,
              onChanged: (val) {
                setState(() {
                  _selectedReason = val;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: DriverDeclineReason.values.map((reason) {
                  return RadioListTile<DriverDeclineReason>(
                    key: Key('decline_radio_${reason.name}'),
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (val) {
                      setState(() {
                        _selectedReason = val;
                      });
                    },
                    dense: true,
                    activeColor: AppColors.primaryBurgundy,
                    title: Text(
                      reason.displayLabel,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: _selectedReason == reason
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ShadiPrimaryButton(
                key: const Key('confirm_decline_button'),
                text: 'Confirm Decline',
                onPressed: _selectedReason == null
                    ? null
                    : () => widget.onConfirm(_selectedReason!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
