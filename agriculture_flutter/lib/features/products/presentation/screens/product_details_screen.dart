import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/app_entrance.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../cart/data/cart_service.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../../cart/presentation/product_purchase_actions.dart';
import '../../data/models/catalog_models.dart';
import '../../data/services/catalog_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with WidgetsBindingObserver {
  CatalogProduct? _product;
  Object? _error;

  Timer? _refreshTimer;
  bool _refreshing = false;

  bool get _isVisible =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? false);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(_refresh());
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_isVisible) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.productId != widget.productId) {
      _product = null;
      _error = null;
      unawaited(_refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isVisible) {
        unawaited(_refresh());
      }

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

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;

    _refreshing = true;
    final requestedId = widget.productId;

    if (_product == null) {
      setState(() {
        _error = null;
      });
    }

    try {
      final product = await CatalogService.instance.product(requestedId);

      if (!mounted || requestedId != widget.productId) return;

      setState(() {
        _product = product;
        _error = null;
      });
    } catch (error) {
      if (!mounted || requestedId != widget.productId) return;

      setState(() {
        _error = error;

        if (error is CatalogException &&
            (error.needsLogin || error.status == 404)) {
          _product = null;
        }
      });
    } finally {
      _refreshing = false;

      if (mounted && requestedId != widget.productId) {
        unawaited(_refresh());
      }
    }
  }

  Future<void> _openCart() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const CartScreen()));

    if (mounted) {
      await _refresh();
    }
  }

  Widget _tag(String text, IconData icon, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: error
            ? colors.errorContainer
            : colors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: error
              ? colors.error.withValues(alpha: 0.2)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: error ? colors.onErrorContainer : colors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: error ? colors.onErrorContainer : colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(CatalogProduct product) {
    final colors = Theme.of(context).colorScheme;
    final description = product.description?.trim();

    return GlassCatalogCard(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(product.categoryName, Icons.grid_view_rounded),
              _tag(
                product.inStock ? 'In stock' : 'Out of stock',
                product.inStock
                    ? Icons.check_circle_outline
                    : Icons.remove_shopping_cart_outlined,
                error: !product.inStock,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            product.name,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            description == null || description.isEmpty
                ? 'No description has been added yet.'
                : description,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 14,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Price per ${product.unit}',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            product.formattedPrice,
            style: TextStyle(
              color: colors.primary,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                'Stock: ${product.stockQuantity}',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (product.weightKg != null)
                Text(
                  'Weight: ${product.weightKg} kg',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Divider(color: colors.outlineVariant),

          if (product.isFood) ...[
            Text(
              'Nutrition information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if ([
              product.nutritionFacts,
              product.nutritionBasis,
              product.nutritionSourceName,
              product.nutritionSourceUrl,
            ].every((value) => value != null && value.trim().isNotEmpty)) ...[
              Text(product.nutritionBasis!),
              const SizedBox(height: 8),
              Text(product.nutritionFacts!),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Source: ${product.nutritionSourceName}'),
                onPressed: () async {
                  final uri = Uri.tryParse(product.nutritionSourceUrl!);
                  var opened = false;

                  try {
                    if (uri != null &&
                        uri.scheme == 'https' &&
                        uri.host.isNotEmpty &&
                        uri.userInfo.isEmpty) {
                      opened = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  } catch (_) {
                    // Display a recoverable message below.
                  }

                  if (!opened && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the source. Please try again.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ] else
              const Text(
                'Verified nutrition information is not available yet.',
              ),
            const SizedBox(height: 16),
          ],
          ProductPurchaseActions(key: ValueKey(product.id), product: product),
        ],
      ),
    );
  }

  Widget _content() {
    final product = _product;

    if (product == null) {
      if (_error != null) {
        return Center(
          child: SingleChildScrollView(
            child: CatalogMessage(error: _error, onRetry: _refresh),
          ),
        );
      }

      return const Center(child: CircularProgressIndicator());
    }

    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Could not refresh. Showing the last loaded details. '
                'Pull down to retry.',
                style: TextStyle(color: colors.error),
              ),
            ),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: _ProductHeroGallery(
                key: ValueKey(
                  Object.hash(product.id, Object.hashAll(product.images)),
                ),
                images: product.images,
                productName: product.name,
              ),
            ),
          ),

          const SizedBox(height: 20),

          AppEntrance(key: ValueKey(product.id), child: _detailsCard(product)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GlassCatalogBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            'Product Details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: 'Refresh product',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'My cart',
              onPressed: _openCart,
              icon: ValueListenableBuilder<int>(
                valueListenable: CartService.instance.productCount,
                builder: (context, count, child) {
                  return Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    backgroundColor: colors.primary,
                    textColor: colors.onPrimary,
                    child: child,
                  );
                },
                child: const Icon(Icons.shopping_cart_outlined),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: ThemeToggleButton(),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductHeroGallery extends StatefulWidget {
  final List<String> images;
  final String productName;

  const _ProductHeroGallery({
    super.key,
    required this.images,
    required this.productName,
  });

  @override
  State<_ProductHeroGallery> createState() => _ProductHeroGalleryState();
}

class _ProductHeroGalleryState extends State<_ProductHeroGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (!_controller.hasClients) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _photo(String? path) {
    final colors = Theme.of(context).colorScheme;

    final fallback = Center(
      child: Icon(Icons.image_outlined, size: 64, color: colors.primary),
    );

    // Reuse the existing image URL resolver.
    final url = CatalogImage(path).url;

    if (url == null) return fallback;

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.12,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: colors.primaryContainer.withValues(alpha: 0.28),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    color: colors.surface.withValues(alpha: 0.38),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: widget.images.isEmpty
                        ? _photo(null)
                        : PageView.builder(
                            controller: _controller,
                            itemCount: widget.images.length,
                            onPageChanged: (index) {
                              setState(() {
                                _page = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Semantics(
                                image: true,
                                label:
                                    '${widget.productName}, '
                                    'photo ${index + 1} '
                                    'of ${widget.images.length}',
                                child: _photo(widget.images[index]),
                              );
                            },
                          ),
                  ),
                ),
              ),

              Positioned(
                top: 8,
                right: 18,
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: 0.45,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 38,
                      color: colors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 20,
                left: 8,
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: -0.65,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 30,
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (widget.images.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous photo',
                onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                '${_page + 1} / ${widget.images.length}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Next photo',
                onPressed: _page < widget.images.length - 1
                    ? () => _goTo(_page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }
}
