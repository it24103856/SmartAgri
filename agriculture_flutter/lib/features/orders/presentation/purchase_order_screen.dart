import 'package:flutter/material.dart';
import '../../../shared/widgets/order_status_emblem.dart';

import '../../../payments/presentation/payment_result_screen.dart';
import '../data/purchase_service.dart';
import 'dart:async';

class PurchaseOrderScreen extends StatefulWidget {
  final int orderId;

  const PurchaseOrderScreen({super.key, required this.orderId});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen>
    with WidgetsBindingObserver {
  PurchaseTracking? _tracking;
  Timer? _timer;

  bool _loading = false;
  bool _cancelling = false;
  bool _foreground = true;
  String? _error;
  DateTime? _lastUpdated;

  static const _labels = {
    'AwaitingPayment': 'Awaiting payment',
    'Confirmed': 'Order confirmed',
    'Preparing': 'Preparing your order',
    'Packed': 'Order packed',
    'Dispatched': 'Dispatched for delivery',
    'Delivered': 'Delivered',
    'PaymentFailed': 'Payment unsuccessful',
    'PaymentReview': 'Order needs review',
    'Cancelled': 'Order cancelled',
  };

  static const _icons = {
    'AwaitingPayment': Icons.payment_outlined,
    'Confirmed': Icons.check_circle_outline,
    'Preparing': Icons.inventory_2_outlined,
    'Packed': Icons.all_inbox_outlined,
    'Dispatched': Icons.local_shipping_outlined,
    'Delivered': Icons.task_alt,
    'PaymentFailed': Icons.error_outline,
    'PaymentReview': Icons.info_outline,
    'Cancelled': Icons.cancel_outlined,
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    unawaited(_reload());

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_foreground &&
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        unawaited(_reload());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    if (_foreground &&
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted || _loading || _cancelling) return;

    setState(() => _loading = true);

    try {
      final result = await PurchaseService.instance.tracking(widget.orderId);

      if (!mounted) return;

      setState(() {
        _tracking = result;
        _error = null;
        _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();

        if (error is PurchaseException &&
            const [401, 403, 404].contains(error.statusCode)) {
          _tracking = null;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _label(String status) => _labels[status] ?? status;

  String _date(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return 'Time not recorded';

    final date = parsed.toLocal();
    final localizations = MaterialLocalizations.of(context);

    return '${localizations.formatMediumDate(date)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
  }

  Widget _section(String title, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _event({
    required String title,
    required String time,
    required IconData icon,
    bool last = false,
    String? subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Column(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primaryContainer,
                child: Icon(icon, color: colors.primary, size: 21),
              ),
              if (!last)
                Container(width: 2, height: 40, color: colors.outlineVariant),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _statusMessage(PurchaseOrder order) {
    switch (order.status) {
      case 'AwaitingPayment':
        return 'Your order is waiting for payment confirmation.';
      case 'Confirmed':
        return 'Your order has been received and confirmed.';
      case 'Preparing':
        return 'Your items are being prepared.';
      case 'Packed':
        return 'Your items are packed and ready for dispatch.';
      case 'Dispatched':
        return 'Your order has been dispatched for delivery.';
      case 'Delivered':
        return 'Your order has been delivered.';
      case 'PaymentFailed':
        return 'Payment was unsuccessful. Check your payment details.';
      case 'PaymentReview':
        return 'Your order requires review. Please contact support.';
      case 'Cancelled':
        return 'Your order was cancelled. No payment is due.';
      default:
        return 'The latest order status is shown above.';
    }
  }

  Future<void> _cancelOrder() async {
    final order = _tracking?.order;

    if (order == null || !order.canCancel || _loading || _cancelling) {
      return;
    }

    setState(() => _cancelling = true);
    bool attempted = false;

    try {
      final formKey = GlobalKey<FormState>();
      String reason = '';

      final confirmedReason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final colors = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            title: const Text('Cancel this order?'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will cancel the entire order. '
                      'You can place a new order later.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      autofocus: true,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Cancellation reason',
                        hintText: 'Tell us why you want to cancel',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => reason = value,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 5) {
                          return 'Enter at least 5 characters';
                        }
                        if (text.length > 500) {
                          return 'Use 500 characters or fewer';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Keep order'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(dialogContext, reason.trim());
                  }
                },
                child: const Text('Cancel order'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmedReason == null) return;
      attempted = true;

      await PurchaseService.instance.cancelOrder(order.id, confirmedReason);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$error\nRefresh the order to check its current status.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
        // Also refresh after a timeout: cancellation may already have succeeded.
        if (attempted) {
          await _reload();
        }
      }
    }
  }

  Future<void> _continuePayment() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PurchasePaymentScreen(orderId: widget.orderId),
      ),
    );

    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tracking = _tracking;

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh tracking',
            onPressed: _loading ? null : () => _reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: tracking == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loading ? null : () => _reload(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Could not refresh. Showing the last loaded details.\n'
                        '$_error',
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        OrderStatusEmblem(status: tracking.order.status),
                        const SizedBox(height: 12),
                        Text(
                          _label(tracking.order.status),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: OrderStatusEmblem.colorFor(
                              tracking.order.status,
                            ),
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage(tracking.order),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  _section('Order tracking', [
                    _event(
                      title: 'Order placed',
                      time: _date(tracking.order.json['createdAt'] as String?),
                      icon: Icons.shopping_bag_outlined,
                      last: tracking.history.isEmpty,
                    ),

                    for (var i = 0; i < tracking.history.length; i++)
                      _event(
                        title: _label(
                          tracking.history[i]['toStatus'] as String,
                        ),
                        time: _date(
                          tracking.history[i]['createdAt'] as String?,
                        ),
                        icon:
                            _icons[tracking.history[i]['toStatus']] ??
                            Icons.check_circle_outline,
                        last: i == tracking.history.length - 1,
                        subtitle: tracking.history[i]['toStatus'] == 'Cancelled'
                            ? tracking.history[i]['cancellationReason']
                                  as String?
                            : tracking.history[i]['paymentCollected'] == true
                            ? 'Cash payment received'
                            : null,
                      ),

                    if (tracking.history.isEmpty)
                      Text(
                        'Delivery progress updates will appear here.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                  ]),

                  _section('Delivery details', [
                    Text(
                      tracking.order.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(tracking.order.phone),
                    Text(tracking.order.address),
                    Text(tracking.order.city),
                  ]),

                  _section('Your items', [
                    for (final item in tracking.order.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item['quantity']} × Rs. '
                              '${(item['unitPrice'] as num).toStringAsFixed(2)}',
                            ),
                            Text(
                              'Rs. '
                              '${(item['lineTotal'] as num).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Text(
                      'Subtotal: Rs. '
                      '${tracking.order.subtotal.toStringAsFixed(2)}',
                    ),
                    Text(
                      'Delivery: Rs. '
                      '${tracking.order.deliveryFee.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: Rs. ${tracking.order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ]),

                  if (tracking.order.canCancel)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(color: colors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _loading || _cancelling
                            ? null
                            : _cancelOrder,
                        icon: _cancelling
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(
                          _cancelling ? 'Please wait…' : 'Cancel order',
                        ),
                      ),
                    ),

                  _section('Payment', [
                    Text(
                      tracking.order.paymentMethod == 'COD'
                          ? 'Cash on Delivery'
                          : 'PayHere Sandbox',
                    ),
                    Text('Status: ${tracking.order.paymentStatus}'),

                    if (tracking.order.paymentMethod == 'COD' &&
                        tracking.order.paymentStatus == 'Unpaid') ...[
                      const SizedBox(height: 8),
                      const Text('Pay when your order is delivered.'),
                    ],

                    if (tracking.order.pending) ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _continuePayment,
                        child: const Text('Continue payment'),
                      ),
                    ],
                  ]),

                  if (_lastUpdated != null)
                    Text(
                      'Last checked: ${_date(_lastUpdated!.toIso8601String())}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
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
