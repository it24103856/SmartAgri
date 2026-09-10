import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../../shared/widgets/theme_toggle_button.dart';
import '../../products/data/services/catalog_service.dart';
import '../data/cart_service.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CartPage(review: false);
  }
}

class CheckoutScreen extends StatelessWidget {
  final int? productId;
  final int quantity;

  const CheckoutScreen({super.key, this.productId, this.quantity = 1});

  @override
  Widget build(BuildContext context) {
    return _CartPage(review: true, productId: productId, quantity: quantity);
  }
}

class _CartPage extends StatefulWidget {
  final bool review;
  final int? productId;
  final int quantity;

  const _CartPage({required this.review, this.productId, this.quantity = 1});

  @override
  State<_CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<_CartPage> {
  late Future<CartData> _future;
  bool _busy = false;

  Future<CartData> _load() {
    if (widget.productId != null) {
      return CartService.instance.buyNow(widget.productId!, widget.quantity);
    }

    return CartService.instance.load(review: widget.review);
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    if (!mounted || _busy) return;

    setState(() {
      _future = _load();
    });

    try {
      await _future;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      if (error is CatalogException && error.needsLogin) {
        await signOutCustomer(context);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is CatalogException
                ? error.message
                : 'Could not update the cart.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });

        await _refresh();
      }
    }
  }

  Future<void> _checkout() async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
    );

    if (mounted) {
      setState(() {
        _busy = false;
      });

      await _refresh();
    }
  }

  Widget _line(CartLine line) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: CatalogImage(line.imageUrl),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Rs. ${line.unitPrice.toStringAsFixed(2)}'
                        ' / ${line.unit}',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (!line.available)
              Text(
                'Unavailable or insufficient stock. '
                'Reduce quantity or remove this item.',
                style: TextStyle(color: colors.error),
              ),

            if (widget.review)
              Text('Quantity: ${line.quantity}')
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Decrease ${line.name}',
                    onPressed:
                        _busy || line.quantity <= 1 || line.stockQuantity <= 0
                        ? null
                        : () {
                            final quantity = (line.quantity - 1)
                                .clamp(1, line.stockQuantity)
                                .toInt();

                            _change(
                              () => CartService.instance.setQuantity(
                                line.productId,
                                quantity,
                              ),
                            );
                          },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),

                  Text('${line.quantity}'),

                  IconButton(
                    tooltip: 'Increase ${line.name}',
                    onPressed:
                        _busy ||
                            !line.available ||
                            line.quantity >= line.stockQuantity
                        ? null
                        : () => _change(
                            () => CartService.instance.setQuantity(
                              line.productId,
                              line.quantity + 1,
                            ),
                          ),
                    icon: const Icon(Icons.add_circle_outline),
                  ),

                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _change(
                            () => CartService.instance.remove(line.productId),
                          ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                ],
              ),

            Text(
              'Rs. ${line.lineTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.review ? 'Checkout review' : 'My cart'),
        actions: const [ThemeToggleButton(), SizedBox(width: 16)],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: FutureBuilder<CartData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return SingleChildScrollView(
                    child: CatalogMessage(
                      error: snapshot.error,
                      onRetry: _refresh,
                    ),
                  );
                }

                final cart = snapshot.requireData;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_busy) const LinearProgressIndicator(),

                      if (cart.items.isEmpty)
                        const CatalogMessage(message: 'Your cart is empty.')
                      else ...[
                        for (final line in cart.items) _line(line),

                        const Divider(height: 24),

                        Text(
                          'Items subtotal: Rs. '
                          '${cart.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (widget.review) ...[
                          const Text(
                            'Review only. No order has been '
                            'placed and no payment has been '
                            'taken. Delivery charges and '
                            'payment will be added in the '
                            'order step.',
                          ),

                          const SizedBox(height: 16),

                          OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Back'),
                          ),
                        ] else ...[
                          const Text(
                            'Prices and stock are checked '
                            'again when you continue.',
                          ),

                          const SizedBox(height: 12),

                          FilledButton(
                            onPressed: _busy || !cart.canCheckout
                                ? null
                                : _checkout,
                            child: const Text('Proceed to checkout'),
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
