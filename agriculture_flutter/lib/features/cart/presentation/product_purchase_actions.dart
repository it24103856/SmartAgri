import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../products/data/models/catalog_models.dart';
import '../../products/data/services/catalog_service.dart';
import '../data/cart_service.dart';
import 'cart_screen.dart';

class ProductPurchaseActions extends StatefulWidget {
  final CatalogProduct product;

  const ProductPurchaseActions({super.key, required this.product});

  @override
  State<ProductPurchaseActions> createState() => _ProductPurchaseActionsState();
}

class _ProductPurchaseActionsState extends State<ProductPurchaseActions> {
  int _quantity = 1;
  bool _busy = false;
  int _inCart = 0;

  @override
  void initState() {
    super.initState();
    _syncCartQuantity();
  }

  Future<void> _syncCartQuantity() async {
    try {
      await _loadCartQuantity();
    } catch (_) {
      // The add action retries this read and displays connection errors.
    }
  }

  Future<int> _loadCartQuantity() async {
    final productId = widget.product.id;
    final cart = await CartService.instance.load();
    final count = cart.items
        .where((item) => item.productId == productId)
        .fold<int>(0, (total, item) => total + item.quantity);
    if (mounted && widget.product.id == productId) {
      setState(() => _inCart = count);
    }
    return count;
  }

  @override
  void didUpdateWidget(covariant ProductPurchaseActions oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.product.id != widget.product.id) {
      _quantity = 1;
      _inCart = 0;
    }
    _syncCartQuantity();

    final stock = widget.product.stockQuantity;

    if (stock > 0 && _quantity > stock) {
      _quantity = stock;
    }
  }

  Future<void> _add() async {
    if (_busy || !widget.product.inStock) return;

    setState(() {
      _busy = true;
    });

    try {
      final inCart = await _loadCartQuantity();
      if (!mounted) return;
      if (inCart + _quantity > widget.product.stockQuantity) {
        throw CatalogException(
          'You already have $inCart in your cart. '
          'Only ${widget.product.stockQuantity} units are in stock. '
          'Open your cart to adjust the quantity.',
        );
      }
      await CartService.instance.add(widget.product.id, _quantity);
      await _syncCartQuantity();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              if (!mounted) return;

              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
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
                : 'Could not add this product.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _buyNow() async {
    if (_busy || !widget.product.inStock) return;

    setState(() => _busy = true);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CheckoutScreen(productId: widget.product.id, quantity: _quantity),
      ),
    );

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final enabled = !_busy && product.inStock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text(
              'Quantity',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),

            IconButton(
              tooltip: 'Decrease quantity',
              onPressed: enabled && _quantity > 1
                  ? () {
                      setState(() {
                        _quantity--;
                      });
                    }
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),

            Text(product.inStock ? '$_quantity' : '0'),

            IconButton(
              tooltip: 'Increase quantity',
              onPressed: enabled && _quantity < product.stockQuantity
                  ? () {
                      setState(() {
                        _quantity++;
                      });
                    }
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_busy) const LinearProgressIndicator(),

        OutlinedButton.icon(
          onPressed: enabled && _inCart + _quantity <= product.stockQuantity
              ? _add
              : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: Text(
            product.inStock && _inCart >= product.stockQuantity
                ? 'Already in cart'
                : 'Add to Cart',
          ),
        ),

        if (_inCart > 0 && product.inStock)
          TextButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CartScreen(),
                      ),
                    );
                    if (mounted) await _syncCartQuantity();
                  },
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            label: Text('$_inCart already in cart · View cart'),
          ),

        const SizedBox(height: 8),

        FilledButton.icon(
          onPressed: enabled ? _buyNow : null,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: const Text('Buy Now'),
        ),

        if (!product.inStock)
          Text(
            'This product is currently out of stock.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
