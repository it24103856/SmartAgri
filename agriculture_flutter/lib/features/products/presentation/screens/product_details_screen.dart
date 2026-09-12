import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_common.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../data/models/catalog_models.dart';
import '../../data/services/catalog_service.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../../cart/presentation/product_purchase_actions.dart';
import '../../../../shared/widgets/app_entrance.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with WidgetsBindingObserver {
  late Future<CatalogProduct> _productFuture;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _productFuture = CatalogService.instance.product(widget.productId);
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _refresh(silent: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(silent: true);
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      final product = await CatalogService.instance.product(widget.productId);
      if (!mounted) return;
      setState(() {
        _productFuture = Future.value(product);
      });
    } catch (error) {
      if (!mounted) return;
      if (!silent ||
          (error is CatalogException &&
              (error.needsLogin || error.status == 404))) {
        setState(() {
          _productFuture = Future.error(error);
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS (purely visual — no logic changes)
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBanner(CatalogProduct product) {
    final colors = Theme.of(context).colorScheme;
    final inStock = product.inStock;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: inStock
              ? [
                  colors.primaryContainer,
                  colors.primaryContainer.withValues(alpha: 0.55),
                ]
              : [
                  colors.errorContainer,
                  colors.errorContainer.withValues(alpha: 0.55),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: inStock
              ? colors.primary.withValues(alpha: 0.20)
              : colors.error.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: inStock
                  ? colors.primary.withValues(alpha: 0.14)
                  : colors.error.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              inStock
                  ? Icons.check_circle_outline_rounded
                  : Icons.remove_shopping_cart_outlined,
              color: inStock ? colors.primary : colors.error,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inStock ? 'In stock' : 'Out of stock',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: inStock ? colors.primary : colors.error,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  inStock
                      ? '${product.stockQuantity} units available'
                      : '0 units available',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: inStock ? colors.onSurfaceVariant : colors.error,
                  ),
                ),
              ],
            ),
          ),
          if (inStock)
            Icon(Icons.verified_rounded, color: colors.primary, size: 22),
        ],
      ),
    );
  }

  Widget _priceCard(CatalogProduct product) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
            colors.tertiary.withValues(alpha: 0.75),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product.formattedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.scale_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'per ${product.unit}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

          // Category pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              product.categoryName,
              style: TextStyle(
                color: colors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Product name
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 20),

          // Gradient price card
          _priceCard(product),

          const SizedBox(height: 18),

          // Stock banner
          _stockBanner(product),

          const SizedBox(height: 26),
          AppEntrance(
            key: ValueKey(product.id),
            child: ProductPurchaseActions(product: product),
          ),
          const SizedBox(height: 28),

          // Description
          _sectionTitle('About this product'),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withValues(alpha: 0.10)),
            ),
            child: Text(
              description == null || description.isEmpty
                  ? 'No description has been added yet.'
                  : description,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Details'),

          const SizedBox(height: 14),

          _detailRow('Product ID', '#${product.id}'),
          _detailRow('Category', product.categoryName),
          _detailRow('Selling unit', product.unit),

          if (product.weightKg != null)
            _detailRow('Weight', '${product.weightKg} kg'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Product details',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'My cart',
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                );
              },
              icon: Icon(Icons.shopping_cart_outlined, color: colors.primary),
            ),
          ),
          const ThemeToggleButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: FutureBuilder<CatalogProduct>(
              future: _productFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
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
  State<_ProductGallery> createState() => _ProductGalleryState();
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
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
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
                          label:
                              '${widget.productName}, '
                              'photo ${index + 1} '
                              'of ${images.length}',
                          child: CatalogImage(images[index]),
                        );
                      },
                    ),
            ),
          ),
        ),

        if (images.length > 1) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: colors.primary.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous photo',
                    onPressed: _currentPage > 0
                        ? () => _showPhoto(_currentPage - 1)
                        : null,
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Dot indicators
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(images.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next photo',
                    onPressed: _currentPage < images.length - 1
                        ? () => _showPhoto(_currentPage + 1)
                        : null,
                    icon: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
