import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../../shared/widgets/customer_animated_nav_bar.dart';
import '../../orders/presentation/checkout_screen.dart';
import '../../orders/presentation/purchase_order_screen.dart';
import '../../products/data/services/catalog_service.dart';
import '../data/cart_service.dart';

// Existing ProductPurchaseActions imports CheckoutScreen from this file.
export '../../orders/presentation/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<CartData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = CartService.instance.load();
  }

  void _reload() {
    if (!mounted) return;

    final next = CartService.instance.load();

    setState(() {
      _future = next;
    });
  }

  Future<void> _change(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);

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
                : 'Could not update cart.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _future = CartService.instance.load();
        });
      }
    }
  }

  Future<void> _checkout() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
    );

    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          IconButton(
            tooltip: 'My Orders',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              final navigation = CustomerNavigation.maybeOf(context);

              if (navigation != null) {
                navigation.selectTab(3);
                return;
              }

              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const PurchaseHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh cart',
            onPressed: _busy ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<CartData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return CatalogMessage(error: snapshot.error, onRetry: _reload);
            }

            final cart = snapshot.requireData;

            if (cart.items.isEmpty) {
              return const Center(child: Text('Your cart is empty.'));
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_busy) const LinearProgressIndicator(),

                for (final item in cart.items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CatalogImage(item.imageUrl),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Rs. ${item.unitPrice.toStringAsFixed(2)}'
                                      ' / ${item.unit}',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (!item.available)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Unavailable or insufficient stock.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),

                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _busy || item.quantity <= 1
                                    ? null
                                    : () => _change(
                                        () => CartService.instance.setQuantity(
                                          item.productId,
                                          item.quantity - 1,
                                        ),
                                      ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                onPressed:
                                    _busy ||
                                        !item.available ||
                                        item.quantity >= item.stockQuantity
                                    ? null
                                    : () => _change(
                                        () => CartService.instance.setQuantity(
                                          item.productId,
                                          item.quantity + 1,
                                        ),
                                      ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _change(
                                        () => CartService.instance.remove(
                                          item.productId,
                                        ),
                                      ),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove'),
                              ),
                            ],
                          ),

                          Text(
                            'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Text(
                  'Subtotal: Rs. ${cart.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _busy || !cart.canCheckout ? null : _checkout,
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Proceed to checkout'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
