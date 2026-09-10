import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_common.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../data/models/catalog_models.dart';
import '../../data/services/catalog_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  late Future<CatalogProduct> _productFuture;

  @override
  void initState() {
    super.initState();
    _productFuture =
        CatalogService.instance.product(widget.productId);
  }

  Future<void> _refresh() async {
    setState(() {
      _productFuture =
          CatalogService.instance.product(widget.productId);
    });

    try {
      await _productFuture;
    } catch (_) {
      // FutureBuilder displays the error and retry button.
    }
  }

  Widget _detailRow(String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productDetails(CatalogProduct product) {
    final colors = Theme.of(context).colorScheme;
    final description = product.description?.trim();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProductGallery(
            key: ValueKey(product.id),
            images: product.images,
            productName: product.name,
          ),

          const SizedBox(height: 24),

          // Category
          Text(
            product.categoryName,
            style: TextStyle(
              color: colors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          // Product name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 20),

          // Price
          Text(
            product.formattedPrice,
            style: TextStyle(
              color: colors.primary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Price per ${product.unit}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 22),

          // Stock status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: product.inStock
                  ? colors.primaryContainer
                  : colors.errorContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  product.inStock
                      ? Icons.check_circle_outline_rounded
                      : Icons.remove_shopping_cart_outlined,
                  color: product.inStock
                      ? colors.onPrimaryContainer
                      : colors.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    product.inStock
                        ? 'In stock · '
                            '${product.stockQuantity} units available'
                        : 'Out of stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: product.inStock
                          ? colors.onPrimaryContainer
                          : colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Description
          const Text(
            'About this product',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            description == null || description.isEmpty
                ? 'No description has been added yet.'
                : description,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const Divider(height: 36),

          // Additional details
          _detailRow('Product ID', '#${product.id}'),
          _detailRow('Category', product.categoryName),
          _detailRow('Selling unit', product.unit),

          if (product.weightKg != null)
            _detailRow(
              'Weight',
              '${product.weightKg} kg',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 760,
            ),
            child: FutureBuilder<CatalogProduct>(
              future: _productFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState !=
                    ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: SingleChildScrollView(
                      child: CatalogMessage(
                        error: snapshot.error,
                        onRetry: _refresh,
                      ),
                    ),
                  );
                }

                return _productDetails(snapshot.requireData);
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductGallery extends StatefulWidget {
  final List<String> images;
  final String productName;

  const _ProductGallery({
    super.key,
    required this.images,
    required this.productName,
  });

  @override
  State<_ProductGallery> createState() =>
      _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPhoto(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.1,
            child: images.isEmpty
                ? const CatalogImage(null)
                : PageView.builder(
                    controller: _controller,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Semantics(
                        image: true,
                        label: '${widget.productName}, '
                            'photo ${index + 1} '
                            'of ${images.length}',
                        child: CatalogImage(images[index]),
                      );
                    },
                  ),
          ),
        ),

        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: _currentPage > 0
                    ? () => _showPhoto(_currentPage - 1)
                    : null,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                ),
              ),
              Flexible(
                child: Text(
                  '${_currentPage + 1} / ${images.length}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next photo',
                onPressed: _currentPage < images.length - 1
                    ? () => _showPhoto(_currentPage + 1)
                    : null,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}