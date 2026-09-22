import 'package:flutter/material.dart';

import '../../orders/data/purchase_service.dart';
import '../../orders/presentation/checkout_screen.dart';
import '../../orders/presentation/purchase_order_screen.dart';
import '../data/smart_basket_service.dart';
import '../data/smart_basket_delete_service.dart';
import 'smart_basket_product_picker.dart';

String basketStatus(String status) => switch (status) {
  'Pending' => 'Waiting to start',
  'Planning' => 'Preparing your basket',
  'Validating' => 'Checking your basket',
  'AwaitingCustomerReview' => 'Ready for your review',
  'AwaitingApproval' => 'Waiting for admin approval',
  'Approved' => 'Approved — ready to order',
  'Rejected' => 'Not approved',
  'Failed' => 'Could not prepare this basket',
  'Ordered' => 'Order created',
  _ => status,
};

String basketMoney(num value) => 'Rs. ${value.toStringAsFixed(2)}';

class SmartBasketScreen extends StatefulWidget {
  const SmartBasketScreen({super.key});

  @override
  State<SmartBasketScreen> createState() => _SmartBasketScreenState();
}

class _SmartBasketScreenState extends State<SmartBasketScreen> {
  final _api = SmartBasketService.instance;
  final _form = GlobalKey<FormState>();
  final _budget = TextEditingController();
  final _objective = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _requests = [];

  // 0 is a UI-only value for all food categories.
  int _categoryId = 0;
  int _page = 1;
  int _total = 0;

  bool _loading = false;
  bool _creating = false;
  String? _error;

  // Retain the exact request after an uncertain network result.
  Map<String, dynamic>? _pendingCreate;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _budget.dispose();
    _objective.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (_loading || _creating) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await _api.categories();
      final result = await _api.list(page: page);

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _requests = (result['items'] as List)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        _total = (result['totalCount'] as num).toInt();
        _page = page;

        if (_categoryId != 0 &&
            !categories.any((value) => value['id'] == _categoryId)) {
          _categoryId = 0;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SmartBasketDetailScreen(id: id)),
    );

    if (mounted) await _load(1);
  }

  Future<void> _deleteBasket(Map<String, dynamic> basket) async {
    if (_loading ||
        _creating ||
        _pendingCreate != null ||
        basket['canDelete'] != true) {
      return;
    }

    final id = basket['id'] as String;
    var deleted = false;

    // Lock history actions while confirming and deleting.
    setState(() => _loading = true);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete basket?'),
          content: const Text(
            'This basket will be removed from your history '
            'and will no longer be available to order.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep basket'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      await SmartBasketDeleteService.delete(id);

      if (!mounted) return;

      setState(() {
        _requests.removeWhere((value) => value['id'] == id);
        if (_total > 0) _total--;
        _error = null;
      });

      deleted = true;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Basket deleted.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    // Reload page 1 so deleting the last item on a page
    // does not leave the user on an empty history page.
    if (mounted && deleted) {
      await _load(1);
    }
  }

  Future<void> _create() async {
    if (_creating || _loading) return;

    if (_pendingCreate == null) {
      if (!(_form.currentState?.validate() ?? false)) return;

      _pendingCreate = {
        'requestId': PurchaseService.newRequestId(),
        'objective': _objective.text.trim(),
        'budget': double.parse(_budget.text.trim()),
        'categoryId': _categoryId == 0 ? null : _categoryId,
      };
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    String? createdId;

    try {
      final result = await _api.create(_pendingCreate!);

      if (!mounted) return;

      createdId = result['id'] as String;

      setState(() => _pendingCreate = null);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();

        if (error is SmartBasketException && !error.uncertain) {
          _pendingCreate = null;
        }
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }

    if (mounted && createdId != null) {
      await _open(createdId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _creating || _pendingCreate != null;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Basket'),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _loading || _creating ? null : () => _load(_page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Build a basket within your budget',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose all food categories or a single category, '
            'then describe what you want. '
            'You can review the basket before requesting admin approval.',
          ),
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _budget,
                  enabled: !locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Maximum budget (LKR)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    final amount = double.tryParse(text);

                    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text) ||
                        amount == null ||
                        amount < 1 ||
                        amount > 1000000) {
                      return 'Enter 1–1,000,000, with up to 2 decimals.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey(_categoryId),
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Food category',
                    helperText: 'Choose all food categories or one category.',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('All food categories'),
                    ),
                    for (final category in _categories)
                      DropdownMenuItem<int>(
                        value: (category['id'] as num).toInt(),
                        child: Text(
                          category['name'] as String,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: locked || _loading
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _categoryId = value);
                        },
                  validator: (value) =>
                      value == null ? 'Select a category.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _objective,
                  enabled: !locked,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'What would you like?',
                    hintText: 'A mixed food basket. Do not include pumpkin.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 5
                      ? 'Describe your request using at least 5 characters.'
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _loading || _creating ? null : _create,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    _creating
                        ? 'Sending…'
                        : _pendingCreate != null
                        ? 'Retry same request'
                        : 'Create basket',
                  ),
                ),
              ],
            ),
          ),
          if (_pendingCreate != null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'The request has not been confirmed. Retry uses the same '
                'request. If you reopen the app, check history first.',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!, style: TextStyle(color: colors.error)),
            ),
          const Divider(height: 36),
          Text('Your requests', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (!_loading && _requests.isEmpty)
            const Text('No requests on this page. Create your first basket.'),
          for (final basket in _requests)
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_basket_outlined),
                title: Text(
                  basket['objective'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${basketStatus(basket['status'] as String)}\n'
                  'Budget: ${basketMoney(basket['budget'] as num)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: basket['canDelete'] == true
                          ? 'Delete basket'
                          : 'Only finished baskets without orders can be deleted',
                      onPressed:
                          _loading ||
                              _creating ||
                              _pendingCreate != null ||
                              basket['canDelete'] != true
                          ? null
                          : () => _deleteBasket(basket),
                      icon: Icon(
                        Icons.delete_outline,
                        color:
                            basket['canDelete'] == true &&
                                !_loading &&
                                !_creating &&
                                _pendingCreate == null
                            ? colors.error
                            : null,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: _loading || _creating
                    ? null
                    : () => _open(basket['id'] as String),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _loading || _creating || _page <= 1
                    ? null
                    : () => _load(_page - 1),
                child: const Text('Previous'),
              ),
              Text('Page $_page'),
              TextButton(
                onPressed: _loading || _creating || _page * 20 >= _total
                    ? null
                    : () => _load(_page + 1),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SmartBasketDetailScreen extends StatefulWidget {
  final String id;

  const SmartBasketDetailScreen({super.key, required this.id});

  @override
  State<SmartBasketDetailScreen> createState() =>
      _SmartBasketDetailScreenState();
}

class _SmartBasketDetailScreenState extends State<SmartBasketDetailScreen> {
  final _api = SmartBasketService.instance;

  Map<String, dynamic>? _basket;
  List<Map<String, dynamic>> _lines = [];
  Map<String, dynamic>? _pendingReview;

  bool _busy = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _accept(Map<String, dynamic> basket) {
    _basket = basket;
    _lines = (basket['items'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    _dirty = false;
    _pendingReview = null;
  }

  Future<void> _load() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final basket = await _api.get(widget.id);
      if (mounted) setState(() => _accept(basket));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  double get _total => _lines.fold<double>(
    0,
    (sum, line) =>
        sum +
        (line['quantity'] as num).toDouble() *
            (line['unitPrice'] as num).toDouble(),
  );

  Future<void> _addProduct() async {
    final basket = _basket;

    if (_busy ||
        basket == null ||
        _pendingReview != null ||
        basket['status'] != 'AwaitingCustomerReview') {
      return;
    }

    if (_lines.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A basket can contain up to 50 products.'),
        ),
      );
      return;
    }

    final budgetMinor = ((basket['budget'] as num).toDouble() * 100).round();
    final remainingMinor = budgetMinor - (_total * 100).round();

    if (remainingMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Remove a product or reduce quantities to free some budget.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final product = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute<Map<String, dynamic>>(
          builder: (_) => SmartBasketProductPicker(
            workflowId: widget.id,
            version: basket['version'] as String,
            existingIds: _lines
                .map((line) => (line['productId'] as num).toInt())
                .toSet(),
            remainingMinor: remainingMinor,
          ),
        ),
      );

      if (!mounted || product == null) return;

      final productId = (product['productId'] as num).toInt();

      if (_lines.any(
        (line) => (line['productId'] as num).toInt() == productId,
      )) {
        return;
      }

      setState(() {
        _lines.add({
          'productId': productId,
          'productName': product['productName'],
          'unit': product['unit'],
          'unitPrice': product['unitPrice'],
          'quantity': 1,
          'lineTotal': product['unitPrice'],
        });

        _dirty = true;
        _error = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(bool submit) async {
    if (_busy || _basket == null || _lines.isEmpty) return;

    _pendingReview ??= {
      'version': _basket!['version'],
      'submitForApproval': submit,
      'items': [
        for (final line in _lines)
          {'productId': line['productId'], 'quantity': line['quantity']},
      ],
    };

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _api.review(widget.id, _pendingReview!);
      if (mounted) setState(() => _accept(result));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();

        if (error is SmartBasketException && !error.uncertain) {
          _pendingReview = null;

          if (error.statusCode == 409) {
            _error =
                '${error.message}\n'
                'Reload the saved basket before making another change.';
          }
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout() async {
    if (_busy) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CheckoutScreen(smartBasketId: widget.id),
      ),
    );

    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final basket = _basket;
    final status = basket?['status'] as String?;
    final editable = status == 'AwaitingCustomerReview';
    final canEdit = editable && !_busy && _pendingReview == null;
    final budget = (basket?['budget'] as num?)?.toDouble() ?? 0;
    final overBudget = (_total * 100).round() > (budget * 100).round();
    final colors = Theme.of(context).colorScheme;
    final linkedOrder = basket?['linkedOrder'];

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Your basket')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(
                _dirty || _pendingReview != null
                    ? 'Discard local edits and reload'
                    : 'Refresh status',
              ),
            ),
            if (basket != null) ...[
              const SizedBox(height: 16),
              Text(
                basketStatus(status!),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(basket['objective'] as String),
              const SizedBox(height: 8),
              Text('Budget: ${basketMoney(basket['budget'] as num)}'),
              const SizedBox(height: 16),
              if (const {'Pending', 'Planning', 'Validating'}.contains(status))
                const Text(
                  'Your basket is being prepared. '
                  'Refresh shortly to check progress.',
                ),
              if (status == 'AwaitingApproval')
                const Text(
                  'Your basket has been submitted. '
                  'Refresh after the admin reviews it.',
                ),
              if (status == 'Failed')
                const Text(
                  'This request could not be completed. '
                  'Check product availability or contact the administrator '
                  'before creating a new request.',
                ),
              if (status == 'Rejected')
                const Text(
                  'This proposal was not approved. '
                  'Contact the administrator or create a new request.',
                ),
              if (editable) ...[
                OutlinedButton.icon(
                  onPressed: canEdit && _lines.length < 50 ? _addProduct : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add products'),
                ),
                const SizedBox(height: 12),
              ],
              for (final line in _lines)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line['productName'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${basketMoney(line['unitPrice'] as num)}'
                          ' / ${line['unit']}',
                        ),
                        Row(
                          children: [
                            if (editable)
                              IconButton(
                                onPressed:
                                    !canEdit || (line['quantity'] as num) <= 1
                                    ? null
                                    : () => setState(() {
                                        line['quantity'] =
                                            (line['quantity'] as int) - 1;
                                        _dirty = true;
                                      }),
                                icon: const Icon(Icons.remove),
                              ),
                            Text('Quantity: ${line['quantity']}'),
                            if (editable)
                              IconButton(
                                onPressed:
                                    !canEdit ||
                                        (line['quantity'] as num) >= 100000
                                    ? null
                                    : () => setState(() {
                                        line['quantity'] =
                                            (line['quantity'] as int) + 1;
                                        _dirty = true;
                                      }),
                                icon: const Icon(Icons.add),
                              ),
                            const Spacer(),
                            if (editable)
                              IconButton(
                                tooltip: 'Remove product',
                                onPressed: !canEdit
                                    ? null
                                    : () => setState(() {
                                        _lines.remove(line);
                                        _dirty = true;
                                      }),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Total: ${basketMoney(_total)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
              if (overBudget)
                Text(
                  'This basket exceeds your budget.',
                  style: TextStyle(color: colors.error),
                ),
              if (editable) ...[
                const SizedBox(height: 12),
                const Text(
                  'Prices and stock are checked when saving. '
                  'Keep at least one product in the basket.',
                ),
                const SizedBox(height: 12),
                if (_pendingReview != null)
                  FilledButton(
                    onPressed: _busy ? null : () => _save(false),
                    child: const Text('Retry the same review request'),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: _busy || _lines.isEmpty || overBudget
                        ? null
                        : () => _save(false),
                    child: const Text('Save changes'),
                  ),
                  FilledButton(
                    onPressed: _busy || _lines.isEmpty || overBudget
                        ? null
                        : () => _save(true),
                    child: const Text('Submit for admin approval'),
                  ),
                ],
              ],
              if (status == 'Approved') ...[
                const SizedBox(height: 16),
                const Text(
                  'Your basket is approved. '
                  'Prices and availability are checked again at checkout.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _checkout,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Continue to checkout'),
                ),
              ],
              if (linkedOrder is Map) ...[
                const SizedBox(height: 16),
                Text('Order #${linkedOrder['id']} • ${linkedOrder['status']}'),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => PurchaseOrderScreen(
                              orderId: (linkedOrder['id'] as num).toInt(),
                            ),
                          ),
                        ),
                  child: const Text('View order'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
