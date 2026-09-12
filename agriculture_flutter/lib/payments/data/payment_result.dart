enum PaymentOutcome { paid, pending, failed, orderPlaced, refunded }

class PaymentResult {
  final int orderId;

  final double amount;
  final String currency;

  final String paymentMethod;
  final String orderStatus;

  final String? reference;
  final PaymentOutcome outcome;

  const PaymentResult({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.orderStatus,
    required this.outcome,
    this.reference,
  });
}
