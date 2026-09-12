import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_widgets.dart';
import '../../../../shared/widgets/customer_animated_nav_bar.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../../products/data/services/catalog_service.dart';
import '../../../products/presentation/screens/products_screen.dart';
import '../../../cart/presentation/cart_screen.dart';
import '../../../cart/data/cart_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  final String fullName;

  const CustomerHomeScreen({super.key, required this.fullName});

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

  BoxDecoration _heroDecoration() {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primary,
          scheme.primary.withValues(alpha: 0.85),
          scheme.tertiary.withValues(alpha: 0.75),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: scheme.primary.withValues(alpha: 0.16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _hero(CatalogProduct? featured) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: _heroDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative blurred circles
          Positioned(
            top: -60,
            right: -40,
            child: _decorativeCircle(180, Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: -80,
            left: -30,
            child: _decorativeCircle(220, Colors.white.withValues(alpha: 0.07)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'FRESH PICKS',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Everyday\n'),
                          TextSpan(
                            text: 'farm finds.',
                            style: TextStyle(color: Color(0xFFFFF3B0)),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fresh from the farm,\nfor your everyday.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: scheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _openProducts(),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text(
                        'Shop now',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                );

                final photo = ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 112),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    elevation: 3,
                    child: InkWell(
                      onTap: featured == null
                          ? null
                          : () => showCatalogProduct(context, featured.id),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 1.1,
                                child: CatalogImage(featured?.thumbnail),
                              ),
                              if (featured != null)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'FEATURED',
                                      style: TextStyle(
                                        fontSize: 8,
                                        letterSpacing: 0.4,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (featured != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                featured.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                final useColumn =
                    bounds.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;

                if (useColumn) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: 12),
                      Center(child: photo),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 12),
                    SizedBox(width: 112, child: photo),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _heading(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton.icon(
            onPressed: () => _openProducts(),
            icon: const Text('View all'),
            label: const Icon(Icons.arrow_forward_rounded, size: 18),
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _categories(List<CatalogCategory> categories) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104 + MediaQuery.textScalerOf(context).scale(12) * 2.8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];

          return SizedBox(
            width: 88,
            child: Tooltip(
              message: category.name,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openProducts(categoryId: category.id),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            scheme.primary.withValues(alpha: 0.15),
                            scheme.tertiary.withValues(alpha: 0.10),
                          ],
                        ),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(child: CatalogImage(category.imageUrl)),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _marketplaceBanner(CatalogData data) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
      ),
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

    return Scaffold(
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
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [scheme.primary, scheme.tertiary],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      titleSpacing: 10,
                      title: const Text(
                        'SmartAgri',
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
                            valueListenable: CartService.instance.productCount,
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
                        PopupMenuButton<String>(
                          tooltip: 'Account',
                          onSelected: (value) {
                            if (value == 'logout') signOutCustomer(context);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Text(name.isEmpty ? 'Customer' : name),
                            ),
                            const PopupMenuItem(
                              value: 'logout',
                              child: Text('Sign out'),
                            ),
                          ],
                          icon: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $firstName 👋',
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
                              _hero(
                                data.products.items.isEmpty
                                    ? null
                                    : data.products.items.first,
                              ),
                              const SizedBox(height: 24),
                              _buildSearchBar(scheme),
                              const SizedBox(height: 26),
                              if (data.categories.isNotEmpty) ...[
                                _heading('Shop by category'),
                                const SizedBox(height: 12),
                                _categories(data.categories),
                                const SizedBox(height: 26),
                              ],
                              _marketplaceBanner(data),
                              const SizedBox(height: 26),
                              _heading('Latest products'),
                              const SizedBox(height: 12),
                              if (data.products.items.isEmpty)
                                const CatalogMessage(
                                  message:
                                      'New products will appear here '
                                      'when they are available.',
                                )
                              else
                                CatalogGrid(products: data.products.items),
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
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
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
          filled: true,
          fillColor: scheme.surface,
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
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}
