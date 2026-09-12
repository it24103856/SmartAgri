import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../cart/data/cart_service.dart';
import '../../../payments/presentation/payment_result_screen.dart';
import '../../products/data/services/catalog_service.dart';
import '../data/purchase_service.dart';

class CheckoutScreen extends StatefulWidget {
  final int? productId;
  final int quantity;

  const CheckoutScreen({super.key, this.productId, this.quantity = 1});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _form = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();

  late Future<CartData> _future;

  String _method = 'COD';
  bool _busy = false;
  String? _error;

  // Keep the exact same request when retrying an uncertain network result.
  Map<String, dynamic>? _submittedRequest;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<CartData> _load() {
    final id = widget.productId;

    return id == null
        ? CartService.instance.load(review: true)
        : CartService.instance.buyNow(id, widget.quantity);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  String _message(Object error) {
    if (error is CatalogException) return error.message;
    return error.toString();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = value?.trim() ?? '';

          if (text.isEmpty) return '$label is required';

          if (controller == _email &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
            return 'Enter a valid email';
          }

          return null;
        },
      ),
    );
  }

  Future<void> _submit(CartData cart) async {
    if (_busy) return;

    if (_submittedRequest == null &&
        !(_form.currentState?.validate() ?? false)) {
      return;
    }

    _submittedRequest ??= {
      'requestId': PurchaseService.newRequestId(),
      'fromCart': widget.productId == null,
      'fullName': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'paymentMethod': _method,
      'items': [
        for (final line in cart.items)
          {
            'productId': line.productId,
            'quantity': line.quantity,
            'unitPrice': double.parse(line.unitPrice.toStringAsFixed(2)),
          },
      ],
    };

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final order = await PurchaseService.instance.create(_submittedRequest!);

      await CartService.instance.refreshProductCount();

      if (!mounted) return;

      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => PurchasePaymentScreen(orderId: order.id),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      if (error is PurchaseException &&
          (error.statusCode == 401 || error.statusCode == 403)) {
        await signOutCustomer(context);
        return;
      }

      setState(() {
        _error = _message(error);

        if (error is PurchaseException &&
            error.statusCode != null &&
            error.statusCode! >= 400 &&
            error.statusCode! < 500) {
          _submittedRequest = null;

          if (error.statusCode == 409) {
            _future = _load();
          }
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: SafeArea(
          child: FutureBuilder<CartData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_message(snapshot.error!)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            final next = _load();

                            setState(() {
                              _future = next;
                            });
                          },
                          child: const Text('Reload checkout'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final cart = snapshot.requireData;

              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Order summary',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    for (final item in cart.items)
                      Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.quantity} × '
                            'Rs. ${item.unitPrice.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    Text('Subtotal: Rs. ${cart.subtotal.toStringAsFixed(2)}'),
                    const Text('Delivery: Free'),
                    const SizedBox(height: 6),
                    Text(
                      'Total: Rs. ${cart.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const Divider(height: 36),

                    AbsorbPointer(
                      absorbing: _busy || _submittedRequest != null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Delivery details',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _field(_name, 'Full name'),
                          _field(
                            _email,
                            'Email',
                            keyboard: TextInputType.emailAddress,
                          ),
                          _field(
                            _phone,
                            'Phone',
                            keyboard: TextInputType.phone,
                          ),
                          _field(_address, 'Address', lines: 2),
                          _field(_city, 'City'),

                          const Text(
                            'Payment method',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),

                          DropdownButtonFormField<String>(
                            initialValue: 'COD',
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'COD',
                                child: Text('Cash on Delivery'),
                              ),
                              DropdownMenuItem(
                                value: 'PAYHERE',
                                child: Text('Online payment — Sandbox'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _method = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_submittedRequest != null)
                        const Text(
                          'Retry will check the same order request. '
                          'Keep this screen open while retrying.',
                        ),
                      const SizedBox(height: 14),
                    ],

                    FilledButton.icon(
                      onPressed: _busy || !cart.canCheckout
                          ? null
                          : () => _submit(cart),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _method == 'COD'
                                  ? Icons.shopping_bag_outlined
                                  : Icons.lock_outline,
                            ),
                      label: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          _busy
                              ? 'Creating order…'
                              : _submittedRequest != null
                              ? 'Retry same order'
                              : _method == 'COD'
                              ? 'Place Order'
                              : 'Pay Now',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
