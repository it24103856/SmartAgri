import 'package:flutter/material.dart';

import '../../../../shared/widgets/catalog_widgets.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../../products/data/services/catalog_service.dart';
import '../../../products/presentation/screens/products_screen.dart';

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
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;

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
    if (_openingProducts) return;

    _openingProducts = true;

    try {
      await Navigator.of(context).push(
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

  Widget _heading(String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(
          onPressed: () => _openProducts(),
          child: const Text('View all →'),
        ),
      ],
    );
  }

  Widget _hero(CatalogProduct? featured) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE SMARTAGRI MARKET',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Everyday\n'),
                    TextSpan(
                      text: 'farm finds.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Discover products for your everyday needs.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => _openProducts(),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Browse'),
              ),
            ],
          );

          final photo = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: featured == null
                    ? null
                    : () => showCatalogProduct(context, featured.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 0.95,
                      child: CatalogImage(featured?.thumbnail),
                    ),
                    if (featured != null)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          featured.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );

          final useColumn =
              bounds.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;

          if (useColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: 20),
                Center(child: photo),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 6, child: copy),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: Center(child: photo)),
            ],
          );
        },
      ),
    );
  }

  Widget _categories(List<CatalogCategory> categories) {
    return SizedBox(
      height: 104 + MediaQuery.textScalerOf(context).scale(12) * 2.8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];

          return SizedBox(
            width: 86,
            child: Tooltip(
              message: category.name,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openProducts(categoryId: category.id),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final name = widget.fullName.trim();

    final firstName = name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;

    return Scaffold(
      appBar: AppBar(
        leading: Icon(
          Icons.eco_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 30,
        ),
        titleSpacing: 0,
        title: const Text(
          'SmartAgri',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
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
              const PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: FutureBuilder<CatalogData>(
            future: _future,
            builder: (context, snapshot) {
              final data = snapshot.data;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Welcome back, $firstName 👋',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(70),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      CatalogMessage(error: snapshot.error, onRetry: _refresh)
                    else if (data != null) ...[
                      _hero(
                        data.products.items.isEmpty
                            ? null
                            : data.products.items.first,
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _search,
                        maxLength: 100,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          _openProducts(search: value.trim());
                        },
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          counterText: '',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton.filled(
                            tooltip: 'Search and filter',
                            onPressed: () {
                              _openProducts(search: _search.text.trim());
                            },
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (data.categories.isNotEmpty) ...[
                        _heading('Shop by category'),
                        const SizedBox(height: 12),
                        _categories(data.categories),
                      ],
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Explore the marketplace',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${data.products.totalCount} products '
                                    'across ${data.categories.length} categories.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Browse all products',
                              onPressed: () => _openProducts(),
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
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
                      const SizedBox(height: 24),
                      Text(
                        'Prices are shown per listed unit. '
                        'Tap a product to see its details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _openProducts();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Products',
          ),
        ],
      ),
    );
  }
}
