import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/shadi_card.dart';
import '../../../../core/widgets/shadi_error_view.dart';
import '../../../../core/widgets/shadi_loading_indicator.dart';
import '../../../../core/widgets/shadi_primary_button.dart';
import '../../../../core/widgets/shadi_secondary_button.dart';
import '../domain/entities/booking_status.dart';
import '../domain/entities/booking_submission_result.dart';

/// Provider fetching submission result by booking ID.
final submissionResultProvider =
    FutureProvider.family<BookingSubmissionResult?, String>((
  ref,
  bookingId,
) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final res = await repo.getSubmissionResult(bookingId);
  return res.dataOrNull;
});

/// Milestone 4B: Customer Booking Submission Result Screen.
///
/// Displays server-authoritative submitted status ("Request Submitted" /
/// "Awaiting Confirmation"). Does NOT display "Confirmed" prematurely.
class BookingResultScreen extends ConsumerWidget {
  final String bookingId;

  const BookingResultScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync = ref.watch(submissionResultProvider(bookingId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go(RoutePaths.customerHome);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.primaryBurgundy,
            ),
            onPressed: () => context.go(RoutePaths.customerHome),
          ),
          title: Text(
            'Submission Status',
            style: AppTypography.displaySmall.copyWith(
              color: AppColors.primaryBurgundy,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: false,
        ),
        body: resultAsync.when(
          loading: () => const Center(
            child: ShadiLoadingIndicator(
              message: 'Retrieving booking record...',
            ),
          ),
          error: (err, _) => ShadiErrorView(
            message: 'Unable to load booking submission record: $err',
            onRetry: () => ref.refresh(submissionResultProvider(bookingId)),
          ),
          data: (result) {
            if (result == null) {
              return ShadiErrorView(
                message:
                    'No booking submission record found for ID: $bookingId',
                onRetry: () => context.go(RoutePaths.customerHome),
              );
            }

            return _buildContent(context, result);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BookingSubmissionResult result) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),

                // Submission Status Badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.verifiedEmerald.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.verifiedEmerald,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  result.status.displayLabel, // e.g. "Request Submitted"
                  style: AppTypography.displayMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                const SizedBox(height: 4),

                Text(
                  result.status == BookingStatus.driverAccepted
                      ? 'Chauffeur Confirmed • Ceremonial Chauffeur Assigned'
                      : 'Booking Request Received • Awaiting Confirmation',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),

                // Booking Reference Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.champagneGold),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Booking Reference: ',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        result.bookingReference,
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryBurgundy,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: result.bookingReference),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reference copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: AppColors.warmGold,
                        ),
                      ),
                    ],
                  ),
                ),

                if (result.isIdempotentReplay) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Idempotent submission replay: Existing reservation intent retrieved.',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Itinerary Summary Card
                ShadiCard(
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
                      _buildInfoRow('Vehicle', result.vehicleName),
                      const SizedBox(height: 8),
                      _buildInfoRow('Ceremony', result.ceremonyType),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Chauffeur Attire',
                        result.ceremonialAttire,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Date & Timing',
                        '${DateFormatter.formatCeremonyDate(result.serviceStartDateTime)} at ${result.serviceStartDateTime.hour.toString().padLeft(2, '0')}:${result.serviceStartDateTime.minute.toString().padLeft(2, '0')} → ${DateFormatter.formatCeremonyDate(result.serviceEndDateTime)} at ${result.serviceEndDateTime.hour.toString().padLeft(2, '0')}:${result.serviceEndDateTime.minute.toString().padLeft(2, '0')} (${result.formattedDuration})',
                      ),
                      if (result.routeDistanceKm != null) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Estimated Route',
                          '~${result.routeDistanceKm!.toStringAsFixed(1)} km (Client Est.)',
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildInfoRow('Pickup', result.pickupAddress),
                      const SizedBox(height: 8),
                      _buildInfoRow('Destination', result.destinationAddress),
                      const SizedBox(height: 8),
                      _buildInfoRow('Contact', result.primaryContactName),
                      if (result.status == BookingStatus.driverAccepted &&
                          result.chauffeurId.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Assigned Chauffeur',
                          'Confirmed (ID: ${result.chauffeurId})',
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Pricing Summary Card
                ShadiCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fare & Deposit Summary',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBurgundy,
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estimated Total',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(
                              result.estimatedTotalPaise,
                            ),
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.primaryBurgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            result.advanceTokenLabel,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(
                              result.advanceTokenPaise,
                            ),
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.warmGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Next Steps Card
                ShadiCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timeline_rounded,
                            color: AppColors.warmGold,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What Happens Next?',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryBurgundy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        result.nextStepMessage,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryLight,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStepItem(
                        step: '1',
                        title: 'Chauffeur Schedule Confirmation',
                        description:
                            'Fleet operations verifies chauffeur availability and procession route.',
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem(
                        step: '2',
                        title: 'Advance Token Lock',
                        description:
                            'You will receive a notification to complete advance deposit once accepted.',
                      ),
                      const SizedBox(height: 8),
                      _buildStepItem(
                        step: '3',
                        title: 'Ceremony Day Dispatch',
                        description:
                            'Live tracking and gate arrival alerts on the wedding day.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
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
                  child: ShadiSecondaryButton(
                    text: 'Return to Home',
                    onPressed: () => context.go(RoutePaths.customerHome),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadiPrimaryButton(
                    text: 'View My Bookings',
                    onPressed: () => context.go(RoutePaths.customerBookings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
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

  Widget _buildStepItem({
    required String step,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: AppColors.primaryBurgundy,
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
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
}
