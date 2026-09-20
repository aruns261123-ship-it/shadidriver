import '../../../../core/result/result.dart';
import '../entities/payment_order.dart';

/// Pure Dart domain contract for payments and advance tokens.
abstract interface class PaymentRepository {
  Future<Result<PaymentOrder>> createAdvanceTokenOrder({
    required String bookingId,
    required String idempotencyKey,
  });

  Future<Result<bool>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  });
}
