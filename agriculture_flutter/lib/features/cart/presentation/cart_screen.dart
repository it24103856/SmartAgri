import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
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
    final colors = Theme.of(context).colorScheme;
    return GlassCatalogBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          title: const Text('My Cart'),
          actions: [
            IconButton(
              tooltip: 'My Orders',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      '${cart.items.length} items in your basket',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  for (final item in cart.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GlassCatalogCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 78,
                                  height: 78,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: CatalogImage(item.imageUrl),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          () =>
                                              CartService.instance.setQuantity(
                                                item.productId,
                                                item.quantity - 1,
                                              ),
                                        ),
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                Text('${item.quantity}'),
                                IconButton(
                                  onPressed:
                                      _busy ||
                                          !item.available ||
                                          item.quantity >= item.stockQuantity
                                      ? null
                                      : () => _change(
                                          () =>
                                              CartService.instance.setQuantity(
                                                item.productId,
                                                item.quantity + 1,
                                              ),
                                        ),
                                  icon: const Icon(Icons.add_rounded),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  GlassCatalogCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Order summary',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Subtotal',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            Text(
                              'Rs. ${cart.subtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review delivery and payment at checkout.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _busy || !cart.canCheckout
                              ? null
                              : _checkout,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            elevation: 4,
                            shadowColor: colors.primary.withValues(alpha: 0.25),
                            shape: const StadiumBorder(),
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Proceed to checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
