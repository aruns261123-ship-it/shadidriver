import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../bookings/data/mock_booking_repository.dart';
import '../domain/entities/payment_order.dart';
import '../domain/repositories/payment_repository.dart';

/// In-memory mock implementation of PaymentRepository for development/testing.
///
/// Simulates the advance-token lifecycle: order creation → gateway checkout →
/// signature verification → booking transition to CONFIRMED. Deterministic
/// failure rules keep the demo honest:
/// - Payment IDs starting with "fail_" simulate a gateway decline.
/// - Any non-"success" signature simulates a tampered/failed verification.
class MockPaymentRepository implements PaymentRepository {
  final Map<String, PaymentOrder> _orders = {};

  /// Booking store transitioned to CONFIRMED after a verified payment.
  final MockBookingRepository? bookingRepository;

  MockPaymentRepository({this.bookingRepository});

  @override
  Future<Result<PaymentOrder>> createAdvanceTokenOrder({
    required String bookingId,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    // Idempotency: replay the existing order for a repeated booking.
    final existing = _orders.values
        .where((o) => o.bookingId == bookingId)
        .toList();
    if (existing.isNotEmpty) {
      return Result.success(existing.first);
    }

    // Amount mirrors the booking's own advance token (20% of estimate),
    // never a hardcoded value.
    final booking =
        (await bookingRepository?.getSubmissionResult(bookingId))?.dataOrNull;
    final amount = booking?.advanceTokenPaise ?? 500000;

    final order = PaymentOrder(
      orderId: 'order_mock_${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      amountCents: amount,
      currency: 'INR',
      status: 'created',
    );
    _orders[order.orderId] = order;
    return Result.success(order);
  }

  /// Simulates the hosted gateway checkout for [order].
  ///
  /// Returns the gateway payment reference. Payments fail when the payer ID
  /// starts with "fail_" (demo decline path); otherwise the order transitions
  /// to "paid".
  @override
  Future<Result<String>> processGatewayCheckout({
    required PaymentOrder order,
    required String payerReference,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));

    if (payerReference.startsWith('fail_')) {
      return const Result.failure(
        ServerFailure('Gateway declined the payment method.'),
      );
    }

    _orders[order.orderId] = PaymentOrder(
      orderId: order.orderId,
      bookingId: order.bookingId,
      amountCents: order.amountCents,
      currency: order.currency,
      status: 'paid',
    );
    return Result.success('pay_${order.orderId.hashCode.abs()}');
  }

  @override
  Future<Result<bool>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    // Server-side rule: only the gateway-signed marker verifies.
    final isValid = signature == 'success' && _orders.containsKey(orderId);
    if (!isValid) {
      return const Result.failure(
        ServerFailure('Payment signature verification failed.'),
      );
    }

    final order = _orders[orderId]!;
    if (order.status != 'paid') {
      return const Result.failure(
        ServerFailure('Order has not been paid yet.'),
      );
    }

    // Advance token verified → reservation officially secured (CONFIRMED).
    bookingRepository?.markBookingConfirmed(order.bookingId);
    return const Result.success(true);
  }
}
