import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/providers/app_providers.dart';
import '../../../bookings/domain/entities/booking_submission_result.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/repositories/payment_repository.dart';

/// Stage of the advance-token checkout journey.
enum PaymentCheckoutStage {
  idle,
  creatingOrder,
  awaitingGateway,
  processingPayment,
  verifying,
  success,
  failed,
}

/// State for the advance-token checkout flow.
@immutable
class PaymentCheckoutState {
  final PaymentCheckoutStage stage;
  final PaymentOrder? order;
  final String? errorMessage;

  /// Booking snapshot the checkout was launched from (for the success screen).
  final BookingSubmissionResult? booking;

  const PaymentCheckoutState({
    this.stage = PaymentCheckoutStage.idle,
    this.order,
    this.errorMessage,
    this.booking,
  });

  bool get isBusy =>
      stage == PaymentCheckoutStage.creatingOrder ||
      stage == PaymentCheckoutStage.awaitingGateway ||
      stage == PaymentCheckoutStage.processingPayment ||
      stage == PaymentCheckoutStage.verifying;

  PaymentCheckoutState copyWith({
    PaymentCheckoutStage? stage,
    PaymentOrder? order,
    String? errorMessage,
    BookingSubmissionResult? booking,
    bool clearOrder = false,
  }) {
    return PaymentCheckoutState(
      stage: stage ?? this.stage,
      order: clearOrder ? null : (order ?? this.order),
      errorMessage: errorMessage,
      booking: booking ?? this.booking,
    );
  }
}

/// Controller for the advance-token checkout flow.
///
/// Orchestrates: order creation → hosted-gateway simulation → server-side
/// signature verification → booking transition to CONFIRMED. A gateway decline
/// or failed verification surfaces the error and keeps the booking unconfirmed,
/// allowing retry.
class PaymentCheckoutController
    extends StateNotifier<PaymentCheckoutState> {
  final PaymentRepository paymentRepository;
  final BookingRepository bookingRepository;
  final String bookingId;

  PaymentCheckoutController({
    required this.paymentRepository,
    required this.bookingRepository,
    required this.bookingId,
  }) : super(const PaymentCheckoutState()) {
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final result = await bookingRepository.getDriverBookingDetails(
      bookingId: bookingId,
      driverId: '', // store lookup is ID-scoped; driver scoping not required
    );
    final booking = result.dataOrNull;
    if (booking != null && mounted) {
      state = state.copyWith(booking: booking);
    }
  }

  /// Full checkout pipeline. Returns true when the booking is CONFIRMED.
  Future<bool> payAdvanceToken({String payerReference = 'upi_rajesh'}) async {
    if (state.isBusy) return false;

    // 1. Create the advance-token order.
    state = state.copyWith(
      stage: PaymentCheckoutStage.creatingOrder,
      clearOrder: true,
    );
    final orderResult = await paymentRepository.createAdvanceTokenOrder(
      bookingId: bookingId,
      idempotencyKey: 'idem_pay_$bookingId',
    );

    PaymentOrder? order;
    var orderFailed = false;
    orderResult.fold(
      (failure) {
        orderFailed = true;
        state = state.copyWith(
          stage: PaymentCheckoutStage.failed,
          errorMessage: failure.message,
        );
      },
      (created) => order = created,
    );
    if (orderFailed || order == null) return false;

    state = state.copyWith(stage: PaymentCheckoutStage.awaitingGateway, order: order);

    // 2. Hosted gateway checkout (simulated).
    state = state.copyWith(stage: PaymentCheckoutStage.processingPayment);
    final checkoutResult = await paymentRepository.processGatewayCheckout(
      order: order!,
      payerReference: payerReference,
    );

    String? paymentId;
    var checkoutFailed = false;
    checkoutResult.fold(
      (failure) {
        checkoutFailed = true;
        state = state.copyWith(
          stage: PaymentCheckoutStage.failed,
          errorMessage: failure.message,
        );
      },
      (paymentIdResolved) => paymentId = paymentIdResolved,
    );
    if (checkoutFailed || paymentId == null) return false;

    // 3. Server-side signature verification → CONFIRMED.
    state = state.copyWith(stage: PaymentCheckoutStage.verifying);
    final verifyResult = await paymentRepository.verifyPaymentSignature(
      orderId: order!.orderId,
      paymentId: paymentId!,
      signature: 'success',
    );

    return verifyResult.fold(
      (failure) {
        state = state.copyWith(
          stage: PaymentCheckoutStage.failed,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(stage: PaymentCheckoutStage.success);
        return true;
      },
    );
  }

  /// Resets the flow for a retry after failure.
  void reset() {
    state = PaymentCheckoutState(booking: state.booking);
  }
}

/// Provider family parameterized by booking ID.
final paymentCheckoutControllerProvider = StateNotifierProvider.autoDispose
    .family<PaymentCheckoutController, PaymentCheckoutState, String>((
      ref,
      bookingId,
    ) {
      return PaymentCheckoutController(
        paymentRepository: ref.watch(paymentRepositoryProvider),
        bookingRepository: ref.watch(bookingRepositoryProvider),
        bookingId: bookingId,
      );
    });
