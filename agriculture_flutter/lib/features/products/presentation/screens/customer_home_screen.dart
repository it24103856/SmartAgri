import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_widgets.dart';
import '../../../../shared/widgets/customer_animated_nav_bar.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../profile/presentation/customer_profile_screen.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../../products/data/services/catalog_service.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../../cart/data/cart_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  final String fullName;
  final String? profileImageUrl;

  const CustomerHomeScreen({
    super.key,
    required this.fullName,
    this.profileImageUrl,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _search = TextEditingController();

  late Future<CatalogData> _future;
  bool _openingProducts = false;

  @override
  void initState() {
    super.initState();
    _future = CatalogService.instance.load(pageSize: 6);
    CartService.instance.productCount.value = 0;
    CartService.instance.refreshProductCount();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    CartService.instance.refreshProductCount();

    setState(() {
      _future = CatalogService.instance.load(pageSize: 6);
    });

    try {
      await _future;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Future<void> _openProducts({int? categoryId, String search = ''}) async {
    final navigation = CustomerNavigation.maybeOf(context);

    if (navigation != null) {
      navigation.openProducts(categoryId, search);
      return;
    }

    // Also supports opening this screen outside CustomerShell.
    if (_openingProducts) return;

    _openingProducts = true;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProductsScreen(
            initialCategoryId: categoryId,
            initialSearch: search,
          ),
        ),
      );

      if (mounted) await _refresh();
    } finally {
      _openingProducts = false;
    }
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS (purely visual — no logic changes)
  // ---------------------------------------------------------------------------

  Widget _homePhoto(String? path, {BoxFit fit = BoxFit.contain}) {
    final url = CatalogImage(path).url;
    final colors = Theme.of(context).colorScheme;
    final fallback = Icon(Icons.eco_rounded, size: 34, color: colors.primary);
    return url == null
        ? Center(child: fallback)
        : Image.network(
            url,
            fit: fit,
            errorBuilder: (_, error, stack) => Center(child: fallback),
          );
  }

  Widget _hero(CatalogProduct? featured) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassCatalogCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [
                    colors.primaryContainer.withValues(alpha: 0.75),
                    colors.surface.withValues(alpha: 0.1),
                  ]
                : const [Color(0xBBA9DCC4), Color(0x55F9E7BC)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FRESH FROM THE FARM',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fresh picks.\nNaturally good.',
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'From local growers.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _openProducts(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 40),
                      shape: const StadiumBorder(),
                      elevation: 3,
                      shadowColor: colors.primary.withValues(alpha: 0.25),
                    ),
                    child: const Text(
                      'Shop now',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              );
              final photo = Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: featured == null
                      ? null
                      : () => showCatalogProduct(context, featured.id),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 112,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _homePhoto(featured?.thumbnail),
                        ),
                      ),
                      if (featured != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            featured.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
              if (bounds.maxWidth < 250 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    copy,
                    const SizedBox(height: 12),
                    Center(child: SizedBox(width: 130, child: photo)),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 6, child: copy),
                  const SizedBox(width: 8),
                  Expanded(flex: 5, child: photo),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _openProducts(),
          child: const Text('See all', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _categories(List<CatalogCategory> categories) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, bounds) {
        final columns = MediaQuery.textScalerOf(context).scale(12) > 17 ? 3 : 4;
        final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 14,
          children: [
            for (final category in categories)
              SizedBox(
                width: width,
                child: Tooltip(
                  message: category.name,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openProducts(categoryId: category.id),
                      child: Column(
                        children: [
                          GlassCatalogCard(
                            radius: 16,
                            padding: const EdgeInsets.all(8),
                            child: AspectRatio(
                              aspectRatio: 1.12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _homePhoto(category.imageUrl),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _marketplaceBanner(CatalogData data) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCatalogCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.storefront_outlined,
              size: 28,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore the marketplace',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  '${data.products.totalCount} products '
                  'across ${data.categories.length} categories.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Browse all products',
              onPressed: () => _openProducts(),
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.fullName.trim();

    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;

    final scheme = Theme.of(context).colorScheme;

    return GlassCatalogBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: FutureBuilder<CatalogData>(
              future: _future,
              builder: (context, snapshot) {
                final data = snapshot.data;

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Custom gradient app bar
                      SliverAppBar(
                        pinned: true,
                        expandedHeight: 0,
                        toolbarHeight: 70,
                        backgroundColor: scheme.surface,
                        elevation: 0,
                        scrolledUnderElevation: 2,
                        leading: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                width: 40,
                                height: 40,
                                fit: BoxFit.contain,
                                semanticLabel: 'SmartAgri logo',
                              ),
                            ),
                          ),
                        ),
                        titleSpacing: 10,
                        title: const Text(
                          '🌱 AgriLink',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 0.3,
                          ),
                        ),
                        actions: [
                          IconButton(
                            tooltip: 'My cart',
                            onPressed: () {
                              final navigation = CustomerNavigation.maybeOf(
                                context,
                              );

                              if (navigation != null) {
                                navigation.selectTab(2);
                                return;
                              }

                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            },
                            icon: ValueListenableBuilder<int>(
                              valueListenable:
                                  CartService.instance.productCount,
                              builder: (context, count, child) => Badge(
                                isLabelVisible: count > 0,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                label: Text('$count'),
                                child: child,
                              ),
                              child: const Icon(Icons.shopping_cart_outlined),
                            ),
                          ),
                          const ThemeToggleButton(),
                          IconButton(
                            tooltip: 'My Profile',
                            icon:
                                widget.profileImageUrl?.trim().isNotEmpty ??
                                    false
                                ? ProfileAvatar(
                                    imageUrl: widget.profileImageUrl,
                                    size: 36,
                                  )
                                : const Icon(Icons.account_circle_outlined),
                            onPressed: () {
                              final navigation = CustomerNavigation.maybeOf(
                                context,
                              );

                              if (navigation != null) {
                                navigation.selectTab(3);
                                return;
                              }

                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CustomerProfileScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello , $firstName 👋',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (snapshot.connectionState !=
                                  ConnectionState.done)
                                const Padding(
                                  padding: EdgeInsets.all(70),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              else if (snapshot.hasError)
                                CatalogMessage(
                                  error: snapshot.error,
                                  onRetry: _refresh,
                                )
                              else if (data != null) ...[
                                _buildSearchBar(scheme),
                                const SizedBox(height: 16),
                                _hero(
                                  data.products.items.isEmpty
                                      ? null
                                      : data.products.items.first,
                                ),
                                const SizedBox(height: 18),
                                if (data.categories.isNotEmpty) ...[
                                  _categories(data.categories),
                                  const SizedBox(height: 12),
                                ],
                                _heading('Latest products'),
                                const SizedBox(height: 12),
                                if (data.products.items.isEmpty)
                                  const CatalogMessage(
                                    message:
                                        'New products will appear here '
                                        'when they are available.',
                                  )
                                else
                                  CatalogGrid(
                                    products: data.products.items,
                                    compact: true,
                                  ),
                                const SizedBox(height: 22),
                                _marketplaceBanner(data),
                                const SizedBox(height: 28),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      'Prices are shown per listed unit. '
                                      'Tap a product to see its details.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final searchTint = isDark
        ? const Color(0xFF14532D)
        : const Color(0xFFDCFCE7);
    final searchBorder = const Color(0xFF22C55E).withValues(alpha: 0.25);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: _search,
        maxLength: 100,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _openProducts(search: value.trim());
        },
        decoration: InputDecoration(
          hintText: 'Search fresh products...',
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          filled: true,
          fillColor: searchTint.withValues(alpha: isDark ? 0.45 : 0.65),
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6),
            child: IconButton.filled(
              tooltip: 'Search and filter',
              onPressed: () {
                _openProducts(search: _search.text.trim());
              },
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: searchBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: searchBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}
