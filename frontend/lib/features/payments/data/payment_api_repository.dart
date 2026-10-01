import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/result/result.dart';
import '../domain/entities/payment_order.dart';
import '../domain/repositories/payment_repository.dart';

/// Real backend payment repository.
///
/// Orders are created server-side with amounts from the booking row (never
/// client input). Capture requires a gateway signature that only the hosted
/// gateway can produce — the client can NEVER mark a payment successful by
/// itself.
///
/// PRODUCTION NOTE: `processGatewayCheckout` talks to the backend's DEV
/// checkout (a server-signed simulation that REFUSES to run when
/// NODE_ENV=production). A production build must swap this leg for the real
/// hosted-gateway flow (Razorpay checkout SDK → /payments/verify with the
/// gateway's HMAC signature) once PAYMENT_KEY_ID/PAYMENT_KEY_SECRET are
/// configured — see docs/PRODUCTION_SETUP.md.
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
        // Payment row id — every later leg (checkout, verify) addresses the
        // payment by this server-issued id.
        paymentId: (data['payment_id'] as String?) ?? '',
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
      // DEV-ONLY simulated hosted checkout: the SERVER signs and captures
      // through the real capture path (the endpoint throws in production).
      // The client never touches gateway secrets. Returns the payment row id
      // so the caller can run the signature-verification leg against the
      // right payment.
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/payments/dev/checkout',
        data: {
          'paymentId': order.paymentId,
          'gatewayOrderId': order.orderId,
          // Simulation-only references (the dev endpoint ignores them; the
          // DTO still requires well-formed values).
          'gatewayPaymentId': 'dev_${order.orderId}',
          'signature': 'dev_checkout_simulated',
        },
      );
      if (order.paymentId.isEmpty) {
        return const Result.failure(
          ServerFailure(
            'Order payload is missing the server payment id.',
            'PAYMENT_ORDER_INVALID',
          ),
        );
      }
      // 'already_captured' is a success: the payment was captured earlier.
      return Result.success(order.paymentId);
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
      // After a DEV checkout the payment is already captured server-side, so
      // this leg is a formality and the placeholder signature is never
      // HMAC-checked. The wire DTO requires >= 8 chars, so short dev
      // placeholders are tagged — a REAL hosted flow passes the gateway's
      // 64-char HMAC here unchanged.
      final wireSignature =
          signature.length >= 8 ? signature : '${signature}_dev';
      await _client.post<Map<String, dynamic>>(
        '${AppConstants.apiV1Prefix}/payments/verify',
        data: {
          'paymentId': paymentId,
          'gatewayOrderId': orderId,
          'gatewayPaymentId': paymentId,
          'signature': wireSignature,
        },
      );
      return const Result.success(true);
    } catch (e) {
      return Result.failure(mapDioError(e));
    }
  }
}
