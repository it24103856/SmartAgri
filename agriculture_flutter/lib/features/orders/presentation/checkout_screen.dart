import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';

import '../../../shared/widgets/catalog_common.dart';
import '../../cart/data/cart_service.dart';
import '../../../payments/presentation/payment_result_screen.dart';
import '../../products/data/services/catalog_service.dart';
import '../data/purchase_service.dart';
import '../../smart_basket/data/smart_basket_service.dart';
import 'dart:async';

import '../../profile/data/customer_profile_service.dart';
import '../../../core/utils/token_storage.dart';
import '../../farmer/data/services/farmer_profile_service.dart';
import 'purchase_order_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final int? productId;
  final int quantity;
  final Map<String, String>? deliveryDetails;
  final String? smartBasketId;

  const CheckoutScreen({
    super.key,
    this.productId,
    this.quantity = 1,
    this.deliveryDetails,
    this.smartBasketId,
  }) : assert(productId == null || smartBasketId == null);

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

  final Set<TextEditingController> _editedFields = {};

  bool _profileLoading = true;
  String? _profileNotice;

  late Future<CartData> _future;
  Map<String, dynamic>? _approvedBasket;

  Future<Map<String, dynamic>>? _bankFuture;
  bool get _review => widget.deliveryDetails != null;

  String _method = 'COD';
  bool _isFarmer = false;
  bool _busy = false;
  String? _error;

  // Keep the exact same request when retrying an uncertain network result.
  Map<String, dynamic>? _submittedRequest;

  @override
  void initState() {
    super.initState();

    _future = _load();

    if (_review) {
      final details = widget.deliveryDetails!;
      _name.text = details['fullName']!;
      _email.text = details['email']!;
      _phone.text = details['phone']!;
      _address.text = details['address']!;
      _city.text = details['city']!;
      _bankFuture = _loadBank();
    }
    unawaited(_loadProfileDetails());
  }

  Future<Map<String, dynamic>> _loadBank() async {
    final response = await ApiClient.instance.dio.get(
      '/order-payments/bank-details',
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  void _buyNow() {
    if (!(_form.currentState?.validate() ?? false)) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          productId: widget.productId,
          quantity: widget.quantity,
          smartBasketId: widget.smartBasketId,
          deliveryDetails: {
            'fullName': _name.text.trim(),
            'email': _email.text.trim(),
            'phone': _phone.text.trim(),
            'address': _address.text.trim(),
            'city': _city.text.trim(),
          },
        ),
      ),
    );
  }

  Widget _bankDetails() => FutureBuilder<Map<String, dynamic>>(
    future: _bankFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return Column(
          children: [
            const Text('Could not load bank details.'),
            TextButton(
              onPressed: () => setState(() => _bankFuture = _loadBank()),
              child: const Text('Retry bank details'),
            ),
          ],
        );
      }
      final data = snapshot.requireData;
      final bank = data['bank'] as Map;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_outlined),
                  SizedBox(width: 10),
                  Text(
                    'Bank details',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (data['bankConfigured'] == true) ...[
                for (final field in {
                  'bankName': 'Bank',
                  'accountName': 'Account holder',
                  'accountNumber': 'Account number',
                  'branch': 'Branch',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SelectableText('${field.value}: ${bank[field.key]}'),
                  ),
                const Text(
                  'After placing your bank transfer order, upload your receipt to confirm payment.',
                ),
              ] else
                const Text('Bank details are not configured. Contact admin.'),
            ],
          ),
        ),
      );
    },
  );

  bool _fillProfileField(TextEditingController controller, String? value) {
    final text = value?.trim() ?? '';

    // Preserve anything the customer has typed or deliberately cleared.
    if (_editedFields.contains(controller) ||
        controller.text.isNotEmpty ||
        text.isEmpty) {
      return false;
    }

    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    return true;
  }

  Future<void> _loadProfileDetails() async {
    try {
      final farmer = await TokenStorage.instance.getRole() == 'FARMER';
      if (!mounted) return;
      setState(() {
        _isFarmer = farmer;
        if (farmer) _method = 'BANK_TRANSFER';
      });
      final user = farmer
          ? await FarmerProfileService.instance.load()
          : await CustomerProfileService.instance.load();

      if (!mounted) return;

      // Do not change delivery details after order submission has started.
      if (_busy || _submittedRequest != null) return;

      var filledCount = 0;

      if (_fillProfileField(_name, user.fullName)) filledCount++;
      if (_fillProfileField(_email, user.email)) filledCount++;
      if (_fillProfileField(_phone, user.phone)) filledCount++;
      if (_fillProfileField(_address, user.address)) filledCount++;
      if (_fillProfileField(_city, user.city)) filledCount++;

      setState(() {
        _profileNotice = filledCount > 0
            ? 'Saved details added. Check your delivery address before ordering.'
            : 'Enter or review your delivery details below.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        if (error is CustomerProfileException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _profileNotice = error.message;
        } else {
          _profileNotice =
              'Saved details could not be loaded. '
              'You can enter your delivery details manually.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<CartData> _load() async {
    final basketId = widget.smartBasketId;

    if (basketId == null) {
      final id = widget.productId;

      return id == null
          ? await CartService.instance.load(review: true)
          : await CartService.instance.buyNow(id, widget.quantity);
    }

    _approvedBasket = null;

    final basket = await SmartBasketService.instance.get(basketId);

    if (basket['linkedOrder'] is Map) {
      final linked = basket['linkedOrder'] as Map;

      throw SmartBasketException(
        'This basket already has order #${linked['id']}. '
        'Go back to the basket and choose View order.',
        409,
      );
    }

    if (basket['status'] != 'Approved') {
      throw const SmartBasketException(
        'This basket is not ready for checkout. '
        'Go back and refresh its approval status.',
        409,
      );
    }

    final basketLines = (basket['items'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();

    if (basketLines.isEmpty) {
      throw const SmartBasketException('The approved basket is empty.');
    }

    final previewLines = <Map<String, dynamic>>[];
    double subtotal = 0;

    for (final line in basketLines) {
      final productId = (line['productId'] as num).toInt();
      final quantity = (line['quantity'] as num).toInt();
      final price = (line['unitPrice'] as num).toDouble();

      final product = await CatalogService.instance.product(productId);

      if (!product.isFood ||
          product.stockQuantity < quantity ||
          (product.price * 100).round() != (price * 100).round() ||
          product.unit != line['unit'] ||
          product.name != line['productName']) {
        throw const SmartBasketException(
          'An approved product changed or has insufficient stock. '
          'Go back to the basket and contact the administrator.',
          409,
        );
      }

      final lineTotal = quantity * price;
      subtotal += lineTotal;

      previewLines.add({
        'productId': productId,
        'quantity': quantity,
        'stockQuantity': product.stockQuantity,
        'name': product.name,
        'unit': product.unit,
        'imageUrl': product.thumbnail,
        'unitPrice': price,
        'lineTotal': lineTotal,
        'available': true,
      });
    }

    final approvedTotal = (basket['proposedTotal'] as num).toDouble();

    if ((subtotal * 100).round() != (approvedTotal * 100).round()) {
      throw const SmartBasketException(
        'Basket total mismatch. Reload the basket.',
        409,
      );
    }

    _approvedBasket = basket;

    return CartData.fromJson({
      'items': previewLines,
      'subtotal': subtotal,
      'canCheckout': true,
    });
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
        onChanged: (_) {
          _editedFields.add(controller);
        },
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.surface,
          prefixIcon: Icon(
            controller == _name
                ? Icons.person_outline
                : controller == _email
                ? Icons.mail_outline
                : controller == _phone
                ? Icons.phone_outlined
                : controller == _city
                ? Icons.location_city_outlined
                : Icons.location_on_outlined,
            color: AppColors.primary,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
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

    if (widget.smartBasketId != null &&
        _approvedBasket == null &&
        _submittedRequest == null) {
      setState(() {
        _error = 'Reload the approved basket before checking out.';
      });
      return;
    }

    if (!_review &&
        _submittedRequest == null &&
        !(_form.currentState?.validate() ?? false)) {
      return;
    }

    _submittedRequest ??= {
      'requestId': PurchaseService.newRequestId(),
      'fromCart': widget.productId == null && widget.smartBasketId == null,
      if (_approvedBasket != null) ...{
        'smartBasketWorkflowId': _approvedBasket!['id'],
        'smartBasketRevision': _approvedBasket!['proposalRevision'],
        'smartBasketVersion': _approvedBasket!['version'],
      },
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
          builder: (_) => order.paymentMethod == 'BANK_TRANSFER'
              ? PurchaseOrderScreen(orderId: order.id)
              : PurchasePaymentScreen(orderId: order.id),
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

  Widget _checkoutHeader(CartData cart) => Container(
    padding: const EdgeInsets.all(24),
    margin: const EdgeInsets.only(bottom: 24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primary, Color(0xFF244B38)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.eco_outlined, color: Color(0xFFCFE5BD), size: 20),
            SizedBox(width: 8),
            Text(
              'FARMERGEE MARKETPLACE',
              style: TextStyle(
                color: Color(0xFFCFE5BD),
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _review
              ? 'One step from your doorstep.'
              : 'Good things are on their way.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _review
              ? 'Review your items and choose how to pay.'
              : 'Tell us where to deliver your order.',
          style: const TextStyle(color: Color(0xFFDCE9DF), height: 1.5),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _step('1', 'Delivery', true),
            _step('2', 'Review & payment', _review),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF658872), height: 1),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '${cart.items.length} ${cart.items.length == 1 ? 'item' : 'items'} in your order',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Flexible(
              child: Text(
                'Rs. ${cart.subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _step(String number, String label, bool active) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: active
            ? const Color(0xFFD9EBC8)
            : const Color(0xFF52745F),
        child: Text(
          number,
          style: TextStyle(
            color: active ? AppColors.textPrimary : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFFB6CABB),
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ],
  );

  Widget _deliveryReview() => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivering to',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                _name.text,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_address.text}, ${_city.text}',
                style: const TextStyle(height: 1.5),
              ),
              Text(
                _phone.text,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _busy || _submittedRequest != null
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Edit'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _review ? 'Review & payment' : 'Checkout',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _checkoutHeader(cart),
                        if (_review) _deliveryReview(),
                        if (_review) ...[
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
                              elevation: 0,
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: CatalogImage(item.imageUrl),
                                  ),
                                ),
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

                          Text(
                            'Subtotal: Rs. ${cart.subtotal.toStringAsFixed(2)}',
                          ),
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
                        ],

                        AbsorbPointer(
                          absorbing: _busy || _submittedRequest != null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_review) ...[
                                const Text(
                                  'Delivery details',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                if (_profileLoading)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Loading saved details… You can also type below.',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                if (!_profileLoading && _profileNotice != null)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _profileNotice!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),

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
                              ],
                              if (_review) ...[
                                _bankDetails(),
                                const SizedBox(height: 20),

                                const Text(
                                  'Payment method',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                DropdownButtonFormField<String>(
                                  key: ValueKey(_isFarmer),
                                  initialValue: _method,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  items: [
                                    if (_isFarmer)
                                      const DropdownMenuItem(
                                        value: 'BANK_TRANSFER',
                                        child: Text(
                                          'Bank transfer — upload receipt',
                                        ),
                                      ),
                                    const DropdownMenuItem(
                                      value: 'COD',
                                      child: Text('Cash on Delivery'),
                                    ),
                                    const DropdownMenuItem(
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
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed:
                              _busy || _profileLoading || !cart.canCheckout
                              ? null
                              : () => _review ? _submit(cart) : _buyNow(),
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                                  : !_review
                                  ? 'Continue to payment'
                                  : _submittedRequest != null
                                  ? 'Retry same order'
                                  : _method == 'BANK_TRANSFER'
                                  ? 'Place order & upload receipt'
                                  : _method == 'COD'
                                  ? 'Place Order'
                                  : 'Pay Now',
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Free delivery on this order',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
