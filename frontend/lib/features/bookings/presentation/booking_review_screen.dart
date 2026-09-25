import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/vehicle_reference.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_secondary_button.dart';
import 'controllers/booking_review_controller.dart';

/// Premium customer booking review screen.
///
/// Displays the full ceremonial itinerary, explicit pricing summary,
/// and allows navigation back to edit or submitting booking intent.
class BookingReviewScreen extends ConsumerWidget {
  final String draftId;

  const BookingReviewScreen({super.key, required this.draftId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingReviewControllerProvider(draftId));
    final controller = ref.read(
      bookingReviewControllerProvider(draftId).notifier,
    );

    // Listen for successful submission to transition to Result screen
    ref.listen<BookingReviewState>(bookingReviewControllerProvider(draftId), (
      previous,
      next,
    ) {
      if (next.isSuccess && next.submissionResult != null) {
        context.pushReplacement(
          RoutePaths.customerBookingResultPath(
            next.submissionResult!.bookingId,
          ),
        );
      }
    });

    if (state.isLoadingDraft) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: ShadiLoadingIndicator(message: 'Loading ceremonial draft...'),
        ),
      );
    }

    if (state.draft == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('Review Booking'),
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primaryBurgundy,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: ShadiErrorView(
          message: state.errorMessage ?? 'Unable to load booking draft.',
          onRetry: () => Navigator.of(context).pop(),
        ),
      );
    }

    final draft = state.draft!;

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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.pushReplacement(
                RoutePaths.customerBookingCreatePath(
                  draft.vehicleId,
                  draftId: draft.id,
                ),
              );
            }
          },
        ),
        title: Text(
          'Review Reservation',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Review Instruction Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.secondarySurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.champagneGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.warmGold,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please review your ceremonial itinerary before submitting your booking request.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 1. Vehicle & Chauffeur Summary
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBurgundy.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.directions_car_rounded,
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
                                    draft.vehicleName,
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  // A full UUID here used to run past the card
                                  // edge; show a short reference and keep the
                                  // exact value available on long-press.
                                  Tooltip(
                                    message: 'Vehicle ID: ${draft.vehicleId}',
                                    child: Text(
                                      '${draft.vehicleClass} • Vehicle ID: '
                                      '${VehicleReference.shorten(draft.vehicleId)}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_rounded,
                              size: 18,
                              color: AppColors.warmGold,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned Chauffeur:',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Verified Professional '
                                '(${VehicleReference.shorten(draft.chauffeurId)})',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Event & Ceremony Details
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ceremony & Attire',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBurgundy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReviewRow(
                          icon: Icons.celebration_rounded,
                          label: 'Occasion',
                          value: draft.ceremonyType,
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.checkroom_rounded,
                          label: 'Chauffeur Attire',
                          value: draft.ceremonialAttire,
                        ),
                        if (draft.specialInstructions.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildReviewRow(
                            icon: Icons.notes_rounded,
                            label: 'Special Note',
                            value: draft.specialInstructions,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Date, Time & Duration
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule & Timing',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBurgundy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReviewRow(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Service Start',
                          value:
                              '${DateFormatter.formatCeremonyDate(draft.serviceStartDateTime)} at ${draft.startTime.format(context)}',
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.stop_circle_outlined,
                          label: 'Service End',
                          value:
                              '${DateFormatter.formatCeremonyDate(draft.serviceEndDateTime)} at ${draft.endTime.format(context)}',
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.timelapse_rounded,
                          label: 'Duration',
                          value: draft.formattedDuration,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Route & Venue Details
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Itinerary & Venue',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBurgundy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReviewRow(
                          icon: Icons.location_city_rounded,
                          label: 'Event City',
                          value: draft.city,
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.my_location_rounded,
                          label: 'Pickup',
                          value: draft.pickupAddress,
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.location_on_rounded,
                          label: 'Destination',
                          value: draft.destinationAddress,
                        ),
                        if (draft.venueName.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildReviewRow(
                            icon: Icons.villa_rounded,
                            label: 'Venue Name',
                            value: draft.venueName,
                          ),
                        ],
                        if (draft.landmark.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildReviewRow(
                            icon: Icons.flag_rounded,
                            label: 'Landmark',
                            value: draft.landmark,
                          ),
                        ],
                        if (draft.routeDistanceKm != null) ...[
                          const SizedBox(height: 8),
                          _buildReviewRow(
                            icon: Icons.alt_route_rounded,
                            label: 'Route Distance',
                            value:
                                '~${draft.routeDistanceKm!.toStringAsFixed(1)} km (Client Est.)',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Host & Guest Details
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host & Passenger Details',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBurgundy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildReviewRow(
                          icon: Icons.person_rounded,
                          label: 'Primary Host',
                          value: draft.primaryContactName,
                        ),
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.phone_rounded,
                          label: 'Contact Phone',
                          value: draft.primaryContactPhone,
                        ),
                        if (draft.alternateContactPhone != null &&
                            draft.alternateContactPhone!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildReviewRow(
                            icon: Icons.contact_phone_rounded,
                            label: 'Alternate Phone',
                            value: draft.alternateContactPhone!,
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildReviewRow(
                          icon: Icons.group_rounded,
                          label: 'Passengers',
                          value: '${draft.passengerCount} Passengers',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Pricing Summary Card
                  ShadiCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fare Summary',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryBurgundy,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Label expands, amount keeps its natural width: a
                        // spaceBetween row with two unbounded Texts overflows
                        // on a narrow phone / large text scale.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Estimated Total (${draft.durationHours} hrs)',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              CurrencyFormatter.formatPaise(
                                draft.estimatedTotalPaise,
                              ),
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.primaryBurgundy,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                draft.advanceTokenLabel,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              CurrencyFormatter.formatPaise(
                                draft.advanceTokenPaise,
                              ),
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.warmGold,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(
                          'Note: No payment is charged right now. Submitting this request transmits your ceremonial schedule for chauffeur verification.',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.textSecondaryLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error Banner if Submission Failed
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.errorRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.errorRed,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.errorRed,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: state.isSubmitting
                                ? null
                                : () => controller.retry(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar: Edit Draft and Submit
          Container(
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
                    flex: 1,
                    child: ShadiSecondaryButton(
                      text: 'Edit Draft',
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              context.push(
                                RoutePaths.customerBookingCreatePath(
                                  draft.vehicleId,
                                  draftId: draft.id,
                                ),
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ShadiPrimaryButton(
                      text: state.isSubmitting
                          ? 'Submitting...'
                          : 'Submit Booking Request',
                      isLoading: state.isSubmitting,
                      onPressed: state.isSubmitting
                          ? null
                          : () => controller.submitBooking(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.warmGold),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
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
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
