import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../domain/entities/payment_order.dart';
import '../domain/repositories/payment_repository.dart';

/// Real backend payment repository.
///
/// Orders are created server-side with amounts from the booking row (never
/// client input). The mock gateway's checkout signature verification runs on
/// the backend — the client can NEVER mark a payment successful by itself.
class PaymentApiRepository implements PaymentRepository {
  final ApiClient _client;

  PaymentApiRepository(this._client);

  @override
  Future<Result<PaymentOrder>> createAdvanceTokenOrder({
    required String bookingId,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/payments/advance-token/order',
        data: {'bookingId': bookingId, 'idempotencyKey': idempotencyKey},
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(PaymentOrder(
        orderId: (data['gateway_order_id'] as String?) ?? '',
        bookingId: bookingId,
        amountCents: parseIntAmount(data['amount_paise']),
        currency: (data['currency'] as String?) ?? 'INR',
        status: 'INITIATED',
      ));
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<String>> processGatewayCheckout({
    required PaymentOrder order,
    required String payerReference,
  }) async {
    try {
      // Simulated hosted checkout: the SERVER signs and captures through the
      // real gateway-verification path. The client never touches gateway
      // secrets. Production swaps this route for the hosted gateway SDK.
      final response = await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/payments/dev/checkout',
        data: {
          'paymentId': payerReference,
          'gatewayOrderId': order.orderId,
        },
      );
      final envelope = ApiEnvelope.fromJson(response.data);
      final data = (envelope.data as Map<String, dynamic>?) ?? const {};
      return Result.success(
        (data['booking_status'] as String?) ?? 'CONFIRMED',
      );
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }

  @override
  Future<Result<bool>> verifyPaymentSignature({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/payments/verify',
        data: {
          'paymentId': paymentId,
          'gatewayOrderId': orderId,
          'gatewayPaymentId': paymentId,
          'signature': signature,
        },
      );
      return const Result.success(true);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }
}
