import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/shadi_card.dart';
import '../../../core/widgets/shadi_primary_button.dart';
import '../../../core/widgets/shadi_secondary_button.dart';
import '../../../core/widgets/shadi_error_view.dart';
import '../../../core/widgets/shadi_loading_indicator.dart';
import '../../bookings/domain/entities/booking_status.dart';
import 'controllers/payment_checkout_controller.dart';

/// Advance Token Checkout — Milestone 5.
///
/// Simulated hosted-gateway payment that locks the ceremonial reservation:
/// order creation → gateway checkout → signature verification → booking
/// transitions to CONFIRMED server-authoritatively.
class PaymentCheckoutScreen extends ConsumerWidget {
  final String bookingId;

  const PaymentCheckoutScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentCheckoutControllerProvider(bookingId));
    final controller = ref.read(
      paymentCheckoutControllerProvider(bookingId).notifier,
    );
    final booking = state.booking;

    if (booking == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: ShadiLoadingIndicator(message: 'Preparing checkout…'),
        ),
      );
    }

    final isConfirmed =
        booking.status == BookingStatus.confirmed ||
        state.stage == PaymentCheckoutStage.success;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isConfirmed ? 'Reservation Secured' : 'Advance Token Checkout',
          style: AppTypography.displaySmall.copyWith(
            color: AppColors.primaryBurgundy,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isConfirmed) ...[
              _buildSuccessCard(context, state),
            ] else ...[
              _buildOrderCard(context, state, booking),
              const SizedBox(height: 16),
              if (state.stage == PaymentCheckoutStage.failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ShadiErrorView(
                    message:
                        state.errorMessage ?? 'Payment failed. Please retry.',
                    onRetry: () {
                      controller.reset();
                    },
                  ),
                ),
              _buildPayButton(context, state, controller),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Demo gateway: any payer reference succeeds • one starting '
                  'with "fail_" simulates a decline.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    PaymentCheckoutState state,
    dynamic booking,
  ) {
    final order = state.order;
    return ShadiCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBurgundy,
            ),
          ),
          const Divider(height: 20),
          _buildInfoRow('Booking Ref', booking.bookingReference),
          const SizedBox(height: 8),
          _buildInfoRow('Ceremony', booking.ceremonyType),
          const SizedBox(height: 8),
          _buildInfoRow('Vehicle', booking.vehicleName),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Amount Due Now',
            CurrencyFormatter.formatPaise(
              order?.amountCents ?? booking.advanceTokenPaise,
            ),
          ),
          if (order != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Gateway Order ID', order.orderId),
          ],
        ],
      ),
    );
  }

  Widget _buildPayButton(
    BuildContext context,
    PaymentCheckoutState state,
    PaymentCheckoutController controller,
  ) {
    if (state.isBusy) {
      return const ShadiPrimaryButton(
        text: 'Processing…',
        isLoading: true,
        onPressed: null,
      );
    }
    return ShadiPrimaryButton(
      key: const Key('pay_advance_token_button'),
      text: 'Pay Advance Token',
      onPressed: () => controller.payAdvanceToken(),
    );
  }

  Widget _buildSuccessCard(BuildContext context, PaymentCheckoutState state) {
    final booking = state.booking;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0x1F66BB6A),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: AppColors.verifiedEmerald,
            size: 48,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Booking Confirmed!',
          style: AppTypography.displayMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBurgundy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your advance token has been received and the ceremonial '
          'reservation is officially secured.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ShadiCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoRow('Booking Ref', booking?.bookingReference ?? '—'),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Token Paid',
                CurrencyFormatter.formatPaise(state.order?.amountCents ?? 0),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Status', 'CONFIRMED'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ShadiPrimaryButton(
          text: 'View My Bookings',
          onPressed: () => context.go(RoutePaths.customerBookings),
        ),
        const SizedBox(height: 12),
        ShadiSecondaryButton(
          text: 'Return to Home',
          onPressed: () => context.go(RoutePaths.customerHome),
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
}
