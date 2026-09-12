import 'package:flutter/material.dart';

import '../../../payments/presentation/payment_result_screen.dart';
import '../data/purchase_service.dart';

class PurchaseOrderScreen extends StatefulWidget {
  final int orderId;

  const PurchaseOrderScreen({super.key, required this.orderId});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  late Future<PurchaseOrder> _future;

  @override
  void initState() {
    super.initState();
    _future = PurchaseService.instance.get(widget.orderId);
  }

  void _reload() {
    setState(() {
      _future = PurchaseService.instance.get(widget.orderId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<PurchaseOrder>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }

          final order = snapshot.requireData;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                order.status,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('Payment: ${order.paymentStatus}'),
              Text(
                order.paymentMethod == 'COD'
                    ? 'Cash on Delivery'
                    : 'PayHere Sandbox',
              ),

              if (order.reviewReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(order.reviewReason!),
                ),

              const Divider(height: 32),

              const Text(
                'Delivery details',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Text(order.fullName),
              Text(order.phone),
              Text(order.address),
              Text(order.city),

              const Divider(height: 32),

              for (final item in order.items)
                Card(
                  child: ListTile(
                    title: Text(item['name'] as String),
                    subtitle: Text(
                      '${item['quantity']} × Rs. '
                      '${(item['unitPrice'] as num).toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      'Rs. ${(item['lineTotal'] as num).toStringAsFixed(2)}',
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              Text('Subtotal: Rs. ${order.subtotal.toStringAsFixed(2)}'),
              Text('Delivery: Rs. ${order.deliveryFee.toStringAsFixed(2)}'),
              Text(
                'Total: Rs. ${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (order.pending) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PurchasePaymentScreen(orderId: order.id),
                      ),
                    );

                    if (mounted) _reload();
                  },
                  child: const Text('Continue payment'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  late Future<List<PurchaseOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = PurchaseService.instance.list();
  }

  void _reload() {
    if (!mounted) return;

    final next = PurchaseService.instance.list();

    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<PurchaseOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snapshot.error}'),
              ),
            );
          }

          final orders = snapshot.requireData;

          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Your latest 50 orders'),
              ),
              for (final order in orders)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text('Order #${order.id}'),
                    subtitle: Text(
                      '${order.status} · ${order.paymentStatus}\n'
                      'Rs. ${order.total.toStringAsFixed(2)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PurchaseOrderScreen(orderId: order.id),
                        ),
                      );

                      if (mounted) _reload();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
