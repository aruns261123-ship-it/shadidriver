import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_status_badge.dart';
import '../domain/entities/booking_summary.dart';
import 'customer_bookings_screen.dart' show customerBookingsProvider;
import '../../reviews/presentation/controllers/review_controller.dart';
import '../../reviews/presentation/widgets/review_submission_sheet.dart';

/// Loads the authoritative booking record by ID (works for any booking in the
/// store — historical and current-session alike).
final bookingDetailProvider =
    FutureProvider.autoDispose.family<BookingSummary?, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final result = await repo.getBookingById(id);
  return result.dataOrNull;
});

/// Customer Booking Detail — full lifecycle timeline for any booking.
///
/// Offers contextual actions: advance-token payment while awaiting acceptance,
/// cancellation pre-ceremony, and post-ceremony review once completed.
class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(bookingDetailProvider(bookingId));
    final reviewed = ref.watch(bookingReviewedProvider(bookingId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Booking Details',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: ShadiLoadingIndicator(message: 'Loading booking record…'),
        ),
        error: (err, _) => ShadiErrorView(
          message: 'Unable to load booking: $err',
          onRetry: () => ref.refresh(bookingDetailProvider(bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return ShadiErrorView(
              message: 'Booking record not found.',
              onRetry: () => context.go(RoutePaths.customerBookings),
            );
          }
          return _buildContent(context, ref, booking, reviewed);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    BookingSummary booking,
    bool reviewed,
  ) {
    final status = booking.status;
    final isConfirmed = status == 'CONFIRMED';
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';
    final canCancel = !isCompleted && !isCancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          Row(
            children: [
              ShadiStatusBadge(
                status: status,
                color: _statusColor(status),
              ),
              const Spacer(),
              Text(
                booking.reference,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBurgundy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ceremony summary card
          ShadiCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${booking.serviceCategory} Ceremony',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _infoRow(
                  'Date & Time',
                  '${DateFormatter.formatCeremonyDate(booking.eventStartTime)} • '
                  '${booking.eventStartTime.hour.toString().padLeft(2, '0')}:'
                  '${booking.eventStartTime.minute.toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 8),
                _infoRow('Duration', booking.formattedDuration),
                const SizedBox(height: 8),
                if (booking.vehicleName.isNotEmpty)
                  _infoRow('Vehicle', booking.vehicleName),
                if (booking.vehicleName.isNotEmpty) const SizedBox(height: 8),
                _infoRow('Pickup', booking.pickupAddress),
                if (booking.destinationAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow('Destination', booking.destinationAddress),
                ],
                if (booking.chauffeurName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow('Chauffeur', booking.chauffeurName),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fare card
          ShadiCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Estimated Total', style: AppTypography.bodyMedium),
                    Text(
                      CurrencyFormatter.formatPaise(booking.totalAmountCents),
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
                    Text('Advance Token', style: AppTypography.labelSmall),
                    Text(
                      CurrencyFormatter.formatPaise(booking.advanceTokenCents),
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

          // Lifecycle timeline
          ShadiCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ceremonial Journey',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryBurgundy,
                  ),
                ),
                const SizedBox(height: 12),
                _timelineItem('Request Submitted', 'Your ceremonial intent was received.', true),
                _timelineItem(
                  'Chauffeur Assigned',
                  'A royal chauffeur was confirmed for your ceremony.',
                  _statusRank(status) >= 2,
                ),
                _timelineItem(
                  'Reservation Secured',
                  'Advance token received; date officially locked.',
                  isConfirmed,
                ),
                _timelineItem(
                  'Ceremony Dispatch',
                  'Chauffeur arrives ahead of the muhurat.',
                  isCompleted || _statusRank(status) >= 4,
                ),
                _timelineItem(
                  'Ceremony Completed',
                  'Service concluded. Settlement recorded.',
                  isCompleted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          if (status == 'DRIVER_ACCEPTED') ...[
            ShadiPrimaryButton(
              key: const Key('detail_pay_cta'),
              text:
                  'Pay Advance Token • ${CurrencyFormatter.formatPaise(booking.advanceTokenCents)}',
              onPressed: () => context.push(
                RoutePaths.customerPaymentCheckoutPath(bookingId),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isCompleted && !reviewed) ...[
            ShadiPrimaryButton(
              key: const Key('detail_review_cta'),
              text: 'Rate Your Ceremony',
              onPressed: () =>
                  showReviewSubmissionSheet(context, ref, bookingId),
            ),
            const SizedBox(height: 12),
          ],
          if (isCompleted && reviewed)
            const ShadiCard(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded,
                      color: AppColors.verifiedEmerald, size: 18),
                  SizedBox(width: 8),
                  Text('Review submitted — thank you!'),
                ],
              ),
            ),
          if (canCancel) ...[
            OutlinedButton(
              key: const Key('detail_cancel_cta'),
              onPressed: () =>
                  _confirmCancellation(context, ref, booking),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel Booking'),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    WidgetRef ref,
    BookingSummary booking,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cancellation is subject to the ceremonial booking policy. '
              'Advance token refunds follow the policy tier.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration:
                  const InputDecoration(hintText: 'Reason (required)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Booking'),
          ),
          ElevatedButton(
            key: const Key('cancel_confirm_button'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              final repo = ref.read(bookingRepositoryProvider);
              final result = await repo.cancelBooking(
                bookingId: booking.id,
                reason: reason,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              if (result.isFailure && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.failureOrNull!.message)),
                );
              }
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.invalidate(bookingDetailProvider(booking.id));
      ref.invalidate(customerBookingsProvider);
    }
  }

  int _statusRank(String status) {
    switch (status) {
      case 'REQUESTED':
        return 1;
      case 'DRIVER_ACCEPTED':
        return 2;
      case 'CONFIRMED':
        return 3;
      case 'DRIVER_ARRIVING':
      case 'ARRIVED':
      case 'TRIP_STARTED':
        return 4;
      case 'COMPLETED':
        return 5;
      default:
        return 0;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
      case 'COMPLETED':
        return AppColors.verifiedEmerald;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red;
      case 'DRIVER_ACCEPTED':
        return Colors.blue.shade700;
      default:
        return AppColors.warmGold;
    }
  }

  Widget _timelineItem(String title, String subtitle, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: done ? AppColors.verifiedEmerald : AppColors.borderLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: done
                        ? AppColors.textPrimaryLight
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
