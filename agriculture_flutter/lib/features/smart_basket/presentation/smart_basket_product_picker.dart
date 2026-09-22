import 'package:flutter/material.dart';

import '../data/smart_basket_service.dart';

class SmartBasketProductPicker extends StatefulWidget {
  final String workflowId;
  final String version;
  final Set<int> existingIds;
  final int remainingMinor;

  const SmartBasketProductPicker({
    super.key,
    required this.workflowId,
    required this.version,
    required this.existingIds,
    required this.remainingMinor,
  });

  @override
  State<SmartBasketProductPicker> createState() =>
      _SmartBasketProductPickerState();
}

class _SmartBasketProductPickerState extends State<SmartBasketProductPicker> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await SmartBasketService.instance.addableProducts(
        widget.workflowId,
      );

      if (!mounted) return;

      if (result['version'] != widget.version) {
        throw const SmartBasketException(
          'This basket changed. Go back and refresh it before adding products.',
          409,
        );
      }

      final products = (result['items'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .where(
            (product) => !widget.existingIds.contains(
              (product['productId'] as num).toInt(),
            ),
          )
          .toList();

      setState(() => _products = products);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _search.trim().toLowerCase();

    final visible = _products.where((product) {
      return (product['productName'] as String).toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add a product')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining budget: Rs. '
              '${(widget.remainingMinor / 100).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose from products checked for this basket. '
              'One selling unit will be added.',
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                      children: [
                        Text(_error!, style: TextStyle(color: colors.error)),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : visible.isEmpty
                  ? Text(
                      _products.isEmpty
                          ? 'No additional eligible products are available. '
                                'You may already have them all in your basket.'
                          : 'No matching products.',
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final product = visible[index];
                        final price = (product['unitPrice'] as num).toDouble();
                        final priceMinor = (price * 100).round();
                        final affordable = priceMinor <= widget.remainingMinor;

                        return Card(
                          child: ListTile(
                            title: Text(product['productName'] as String),
                            subtitle: Text(
                              'Rs. ${price.toStringAsFixed(2)}'
                              ' / ${product['unit']}\n'
                              '${affordable ? 'Available: ${product['stockQuantity']}' : 'Not enough remaining budget'}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: affordable
                                  ? 'Add product'
                                  : 'Reduce your basket total first',
                              onPressed: affordable
                                  ? () => Navigator.of(context).pop(product)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            onTap: affordable
                                ? () => Navigator.of(context).pop(product)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
