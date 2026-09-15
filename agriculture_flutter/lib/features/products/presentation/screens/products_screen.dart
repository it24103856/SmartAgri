import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_widgets.dart';
import '../../../../shared/widgets/customer_animated_nav_bar.dart';
import '../../../cart/data/cart_service.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../data/models/catalog_models.dart';
import '../../data/services/catalog_service.dart';

class ProductsScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String initialSearch;

  const ProductsScreen({
    super.key,
    this.initialCategoryId,
    this.initialSearch = '',
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _scroll = ScrollController();

  late final TextEditingController _search;
  late Future<CatalogData> _future;

  Timer? _debounce;

  int _category = 0;
  int _page = 1;
  String _sort = 'latest';

  static const _sortLabels = {
    'latest': 'Latest',
    'price_asc': 'Price: Low to High',
    'price_desc': 'Price: High to Low',
  };

  @override
  void initState() {
    super.initState();

    _search = TextEditingController(text: widget.initialSearch);

    _category = widget.initialCategoryId ?? 0;
    _future = _fetch();
  }

  Future<CatalogData> _fetch() {
    return CatalogService.instance.load(
      search: _search.text.trim(),
      categoryId: _category == 0 ? null : _category,
      sort: _sort,
      page: _page,
      pageSize: 12,
    );
  }

  void _load({int page = 1}) {
    if (!mounted) return;

    _debounce?.cancel();

    setState(() {
      _page = page;
      _future = _fetch();
    });
  }

  void _onSearchChanged(String value) {
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () => _load());
  }

  Future<void> _refresh() async {
    _load();

    try {
      await _future;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  void _reset() {
    FocusManager.instance.primaryFocus?.unfocus();

    _search.clear();
    _category = 0;
    _sort = 'latest';

    _load();
  }

  void _goToPage(int page) {
    _load(page: page);

    if (_scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _goHome() {
    final navigation = CustomerNavigation.maybeOf(context);

    if (navigation != null) {
      navigation.selectTab(0);
      return;
    }

    Navigator.of(context).maybePop();
  }

  Future<void> _openProduct(int productId) async {
    FocusManager.instance.primaryFocus?.unfocus();

    await showCatalogProduct(context, productId);

    if (mounted) {
      _load(page: _page);
    }
  }

  Future<void> _openCart() async {
    FocusManager.instance.primaryFocus?.unfocus();

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const CartScreen()));

    if (mounted) {
      _load(page: _page);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _filterLabel(String label, IconData icon, {bool selected = false}) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected
            ? colors.primaryContainer
            : colors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected
              ? colors.primary.withValues(alpha: 0.25)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List<CatalogCategory> categories) {
    var categoryLabel = 'Category';

    for (final category in categories) {
      if (category.id == _category) {
        categoryLabel = category.name;
        break;
      }
    }

    if (_category != 0 && categoryLabel == 'Category') {
      categoryLabel = 'Selected category';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Sort products',
            initialValue: _sort,
            onSelected: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              _sort = value;
              _load();
            },
            itemBuilder: (_) => [
              for (final entry in _sortLabels.entries)
                PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            child: _filterLabel(
              _sort == 'latest' ? 'Sort By' : _sortLabels[_sort]!,
              Icons.swap_vert_rounded,
              selected: _sort != 'latest',
            ),
          ),

          const SizedBox(width: 8),

          PopupMenuButton<int>(
            tooltip: 'Choose category',
            initialValue: _category,
            onSelected: (value) {
              FocusManager.instance.primaryFocus?.unfocus();
              _category = value;
              _load();
            },
            itemBuilder: (_) => [
              const PopupMenuItem<int>(
                value: 0,
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.grid_view_outlined, size: 20),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('All categories')),
                  ],
                ),
              ),
              for (final category in categories)
                PopupMenuItem<int>(
                  value: category.id,
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CatalogImage(category.imageUrl),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(category.name)),
                    ],
                  ),
                ),
            ],
            child: _filterLabel(
              categoryLabel,
              Icons.grid_view_outlined,
              selected: _category != 0,
            ),
          ),

          const SizedBox(width: 8),

          TextButton(onPressed: _reset, child: const Text('Reset')),
        ],
      ),
    );
  }

  Widget _results(AsyncSnapshot<CatalogData> snapshot) {
    final colors = Theme.of(context).colorScheme;

    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return SingleChildScrollView(
        child: CatalogMessage(
          error: snapshot.error,
          onRetry: () => _load(page: _page),
        ),
      );
    }

    final results = snapshot.requireData.products;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${results.totalCount} products found',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('See all')),
            ],
          ),

          const SizedBox(height: 16),

          if (results.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 54,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No products found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Try another search or category.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final minWidth = MediaQuery.textScalerOf(context).scale(140);

                final columns = ((constraints.maxWidth + 12) / (minWidth + 12))
                    .floor()
                    .clamp(1, 4)
                    .toInt();

                final cardWidth =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final product in results.items)
                      SizedBox(
                        width: cardWidth,
                        child: _MarketProductCard(
                          key: ValueKey(product.id),
                          product: product,
                          onOpen: () => _openProduct(product.id),
                          onOpenCart: _openCart,
                        ),
                      ),
                  ],
                );
              },
            ),

          if (results.totalPages > 1 || _page > 1) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Previous page',
                  onPressed: _page > 1 ? () => _goToPage(_page - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    'Page $_page',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Next page',
                  onPressed: _page < results.totalPages
                      ? () => _goToPage(_page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
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
          toolbarHeight: 76,
          titleSpacing: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            tooltip: 'Home',
            onPressed: _goHome,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: TextField(
            controller: _search,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            onSubmitted: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              _load();
            },
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: const TextStyle(fontSize: 14),
              counterText: '',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                      icon: const Icon(Icons.close_rounded, size: 19),
                    ),
              filled: true,
              fillColor: colors.surface.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: colors.primary),
              ),
            ),
          ),
          actions: [
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
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: ColoredBox(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: FutureBuilder<CatalogData>(
                  future: _future,
                  builder: (context, snapshot) {
                    return Column(
                      children: [
                        _filters(snapshot.data?.categories ?? []),
                        Expanded(child: _results(snapshot)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketProductCard extends StatefulWidget {
  final CatalogProduct product;
  final Future<void> Function() onOpen;
  final Future<void> Function() onOpenCart;

  const _MarketProductCard({
    super.key,
    required this.product,
    required this.onOpen,
    required this.onOpenCart,
  });

  @override
  State<_MarketProductCard> createState() => _MarketProductCardState();
}

class _MarketProductCardState extends State<_MarketProductCard> {
  bool _adding = false;

  Future<void> _add() async {
    if (_adding || !widget.product.inStock) return;

    setState(() {
      _adding = true;
    });

    try {
      await CartService.instance.add(widget.product.id, 1);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product.name} added to cart'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              if (mounted) {
                widget.onOpenCart();
              }
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
                : 'Could not add this product. Check your cart.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
        });
      }
    }
  }

  String get _weightLabel {
    final weight = widget.product.weightKg;

    if (weight == null || weight <= 0) {
      return widget.product.unit;
    }

    if (weight < 1) {
      return '${(weight * 1000).toStringAsFixed(0)} g';
    }

    return '$weight kg';
  }

  Widget _image() {
    final colors = Theme.of(context).colorScheme;

    final fallback = Center(
      child: Icon(Icons.image_outlined, size: 42, color: colors.primary),
    );

    final url = CatalogImage(widget.product.thumbnail).url;

    if (url == null) return fallback;

    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final colors = Theme.of(context).colorScheme;

    return GlassCatalogCard(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _adding ? null : widget.onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    image: true,
                    label: product.name,
                    child: _image(),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _weightLabel,
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(14) * 2.6,
                      child: Tooltip(
                        message: product.name,
                        child: Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          product.inStock
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          size: 12,
                          color: product.inStock
                              ? colors.primary
                              : colors.error,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.inStock ? 'In stock' : 'Out of stock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: product.inStock
                                  ? colors.onSurfaceVariant
                                  : colors.error,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Tooltip(
                                message: product.formattedPrice,
                                child: Text(
                                  product.formattedPrice,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                'per ${product.unit}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        IconButton.filled(
                          tooltip: 'Add one ${product.name} to cart',
                          onPressed: _adding || !product.inStock ? null : _add,
                          style: IconButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            minimumSize: const Size(48, 48),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: _adding
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : const Icon(Icons.add_rounded, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
