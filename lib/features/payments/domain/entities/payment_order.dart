/// Domain representation of a payment order.
class PaymentOrder {
  final String orderId;
  final String bookingId;
  final int amountCents;
  final String currency;
  final String status;

  const PaymentOrder({
    required this.orderId,
    required this.bookingId,
    required this.amountCents,
    this.currency = 'INR',
    required this.status,
  });
}
