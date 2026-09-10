import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_widgets.dart';
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

  @override
  void initState() {
    super.initState();

    _search = TextEditingController(text: widget.initialSearch);
    _category = widget.initialCategoryId ?? 0;
    _future = _fetch();
  }

  Future<CatalogData> _fetch() {
    return CatalogService.instance.load(
      search: _search.text,
      categoryId: _category == 0 ? null : _category,
      sort: _sort,
      page: _page,
    );
  }

  void _load({int page = 1}) {
    _debounce?.cancel();
    _page = page;

    setState(() {
      _future = _fetch();
    });
  }

  Future<void> _refresh() async {
    _load(page: _page);

    try {
      await _future;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  void _reset() {
    _search.clear();
    _category = 0;
    _sort = 'latest';
    _load();
  }

  void _goToPage(int page) {
    _load(page: page);

    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS (purely visual — no logic changes)
  // ---------------------------------------------------------------------------

  Widget _filterBox(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeading(String title, {String? trailing}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
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
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _filters(List<CatalogCategory> categories) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Floating pill search bar — same style as home page
        Container(
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
            decoration: InputDecoration(
              hintText: 'Search fresh products...',
              counterText: '',
              filled: true,
              fillColor: scheme.surface,
              prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(6),
                child: IconButton.filled(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _search.clear();
                    _load();
                  },
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
            onSubmitted: (_) => _load(),
            onChanged: (_) {
              _debounce?.cancel();

              _debounce = Timer(const Duration(milliseconds: 450), () {
                if (mounted) _load();
              });
            },
          ),
        ),
        const SizedBox(height: 14),
        _filterBox(
          DropdownButton<int>(
            value: _category,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: scheme.primary,
            ),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            items: [
              const DropdownMenuItem(value: 0, child: Text('All categories')),
              if (_category != 0 && !categories.any((c) => c.id == _category))
                DropdownMenuItem(
                  value: _category,
                  child: Text('Category #$_category'),
                ),
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;

              _category = value;
              _load();
            },
          ),
        ),
        const SizedBox(height: 10),
        _filterBox(
          DropdownButton<String>(
            value: _sort,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: scheme.primary,
            ),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Newest first')),
              DropdownMenuItem(
                value: 'price_asc',
                child: Text('Price: low to high'),
              ),
              DropdownMenuItem(
                value: 'price_desc',
                child: Text('Price: high to low'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              _sort = value;
              _load();
            },
          ),
        ),
      ],
    );
  }

  Widget _pagination(CatalogPage page) {
    final scheme = Theme.of(context).colorScheme;

    Widget pageButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? null
              : [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: IconButton.filled(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          pageButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            onPressed: page.page > 1 ? () => _goToPage(page.page - 1) : null,
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Page ${page.page} of ${page.totalPages}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
          ),
          pageButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next page',
            onPressed: page.page < page.totalPages
                ? () => _goToPage(page.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  colors: [scheme.primary, scheme.tertiary],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Explore products',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset'),
              style: TextButton.styleFrom(foregroundColor: scheme.primary),
            ),
          ),
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
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    _filters(data?.categories ?? const <CatalogCategory>[]),
                    const SizedBox(height: 24),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      CatalogMessage(
                        error: snapshot.error,
                        onRetry: () => _load(page: _page),
                      )
                    else if (data != null) ...[
                      _sectionHeading(
                        'Products',
                        trailing: '${data.products.totalCount} items',
                      ),
                      const SizedBox(height: 16),
                      if (data.products.items.isEmpty)
                        const CatalogMessage(
                          message:
                              'No matching products. Try another search '
                              'or reset your filters.',
                        )
                      else
                        CatalogGrid(products: data.products.items),
                      if (data.products.totalPages > 1) ...[
                        const SizedBox(height: 24),
                        _pagination(data.products),
                      ],
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
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) Navigator.pop(context);
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
