import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/order_status_emblem.dart';

import '../../features/cart/data/cart_service.dart';
import '../../features/orders/data/purchase_service.dart';
import '../../features/orders/presentation/purchase_order_screen.dart';

class PurchasePaymentScreen extends StatefulWidget {
  final int orderId;

  const PurchasePaymentScreen({super.key, required this.orderId});

  @override
  State<PurchasePaymentScreen> createState() => _PurchasePaymentScreenState();
}

class _PurchasePaymentScreenState extends State<PurchasePaymentScreen>
    with WidgetsBindingObserver {
  PurchaseOrder? _order;

  Timer? _timer;

  bool _checking = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _refresh();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_order?.pending ?? true) {
        _refresh(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (!mounted || _checking) return;

    setState(() => _checking = true);

    try {
      final order = await PurchaseService.instance.get(widget.orderId);

      if (!mounted) return;

      final newlyConfirmed =
          _order?.status != 'Confirmed' && order.status == 'Confirmed';

      setState(() {
        _order = order;
        _error = null;
      });

      if (newlyConfirmed) {
        unawaited(CartService.instance.refreshProductCount());
      }
    } catch (error) {
      if (mounted && !quiet) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _openPayment() async {
    if (_opening) return;

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final url = await PurchaseService.instance.paymentUrl(widget.orderId);

      if (!mounted) return;

      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!opened) {
        throw const PurchaseException('Could not open the browser.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order payment')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      FilledButton(
                        onPressed: () => _refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final review = order.status == 'PaymentReview';

    final String title;
    final String message;

    if (order.status == 'Cancelled') {
      title = 'Order cancelled';
      message = 'Your order was cancelled. No payment is due.';
    } else if (order.paidAndConfirmed) {
      title = 'Payment Successful!';
      message = 'Your order is confirmed.';
    } else if (order.codConfirmed) {
      title = 'Order Confirmed!';
      message = 'Pay when your order is delivered.';
    } else if (review) {
      title = 'Order needs review';
      message = order.reviewReason ?? 'Please contact support.';
    } else if (order.pending) {
      title = 'Complete your payment';
      message =
          'Open PayHere Sandbox to pay. Return to this app '
          'after finishing payment.';
    } else {
      title = 'Payment ${order.paymentStatus}';
      message =
          'This order has not been confirmed. '
          'Check the status before starting another checkout.';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order payment')),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDDF3F5), Color(0xFFE7F3CD)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_checking) const LinearProgressIndicator(),

              const SizedBox(height: 32),

              Center(child: OrderStatusEmblem(status: order.status)),

              const SizedBox(height: 28),

              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OrderStatusEmblem.colorFor(order.status),
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF35584C), fontSize: 16),
              ),

              const SizedBox(height: 26),

              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Color(0xFF17352C),
                      fontSize: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Total: Rs. ${order.total.toStringAsFixed(2)}'),
                        Text('Order: ${order.status}'),
                        Text('Payment: ${order.paymentStatus}'),
                        Text(
                          order.paymentMethod == 'COD'
                              ? 'Cash on Delivery'
                              : 'PayHere Sandbox',
                        ),
                        if (order.paymentReference != null) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            'Reference: ${order.paymentReference}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              if (order.pending) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _opening ? null : _openPayment,
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(_opening ? 'Opening…' : 'Open payment'),
                ),
              ],

              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: _checking ? null : () => _refresh(),
                child: const Text('Check payment status'),
              ),

              const SizedBox(height: 12),

              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => PurchaseOrderScreen(orderId: order.id),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Order'),
              ),

              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Continue shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
