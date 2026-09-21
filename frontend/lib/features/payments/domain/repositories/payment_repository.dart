import '../../../../core/result/result.dart';
import '../entities/payment_order.dart';

/// Pure Dart domain contract for payments and advance tokens.
abstract interface class PaymentRepository {
  Future<Result<PaymentOrder>> createAdvanceTokenOrder({
    required String bookingId,
    required String idempotencyKey,
  });

  /// Runs the hosted gateway checkout for [order] and returns the gateway
  /// payment reference on success.
  Future<Result<String>> processGatewayCheckout({
    required PaymentOrder order,
    required String payerReference,
  });

  Future<Result<bool>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
