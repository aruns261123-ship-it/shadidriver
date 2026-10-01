/// Domain representation of a payment order.
class PaymentOrder {
  final String orderId;
  final String bookingId;
  final int amountCents;
  final String currency;
  final String status;

  /// Server-side payment row id (returned by the order-creation endpoint).
  /// Capture and verification address the payment by THIS id — the client can
  /// never mark a payment successful by itself. Empty in mock mode, which
  /// issues gateway-local references instead.
  final String paymentId;

  const PaymentOrder({
    required this.orderId,
    required this.bookingId,
    required this.amountCents,
    this.currency = 'INR',
    required this.status,
    this.paymentId = '',
  });
}
