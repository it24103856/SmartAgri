import 'package:agriculture_flutter/features/orders/data/purchase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PurchaseOrder order(String status, String method, String paymentStatus) =>
      PurchaseOrder.fromJson({
        'status': status,
        'payment': {'method': method, 'status': paymentStatus},
      });

  test('payment success remains recognized throughout fulfillment', () {
    for (final status in [
      'Confirmed',
      'Preparing',
      'Packed',
      'Dispatched',
      'Delivered',
    ]) {
      expect(order(status, 'PAYHERE', 'Paid').paidAndConfirmed, isTrue);
      expect(order(status, 'PAYHERE', 'Pending').paidAndConfirmed, isFalse);
      expect(order(status, 'COD', 'Unpaid').codConfirmed, isTrue);
      expect(order(status, 'COD', 'Paid').codConfirmed, isFalse);
      expect(order(status, 'PAYHERE', 'Unpaid').codConfirmed, isFalse);
    }
  });

  test('unaccepted orders do not report confirmation', () {
    for (final status in ['Pending', 'Cancelled', 'Rejected', 'Unknown']) {
      expect(order(status, 'PAYHERE', 'Paid').paidAndConfirmed, isFalse);
      expect(order(status, 'COD', 'Unpaid').codConfirmed, isFalse);
    }
  });
}
