import '../../../../core/result/result.dart';
import '../domain/entities/payment_order.dart';
import '../domain/repositories/payment_repository.dart';

/// In-memory mock implementation of PaymentRepository for development and testing.
class MockPaymentRepository implements PaymentRepository {
  final Map<String, PaymentOrder> _orders = {};

  @override
  Future<Result<PaymentOrder>> createAdvanceTokenOrder({
    required String bookingId,
    required String idempotencyKey,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final order = PaymentOrder(
      orderId: 'order_mock_${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      amountCents: 500000,
      currency: 'INR',
      status: 'created',
    );
    _orders[order.orderId] = order;
    return Result.success(order);
  }

  @override
  Future<Result<bool>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return const Result.success(true);
  }
}
