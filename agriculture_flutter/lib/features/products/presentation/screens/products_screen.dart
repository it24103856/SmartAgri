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

  Widget _filterBox(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _filters(List<CatalogCategory> categories) {
    return Column(
      children: [
        TextField(
          controller: _search,
          maxLength: 100,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search products...',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () {
                _search.clear();
                _load();
              },
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
        const SizedBox(height: 12),
        _filterBox(
          DropdownButton<int>(
            value: _category,
            isExpanded: true,
            underline: const SizedBox.shrink(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore products'),
        actions: [TextButton(onPressed: _reset, child: const Text('Reset'))],
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
                      Text(
                        '${data.products.totalCount} products',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton.filledTonal(
                              tooltip: 'Previous page',
                              onPressed: data.products.page > 1
                                  ? () => _goToPage(data.products.page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Flexible(
                              child: Text(
                                'Page ${data.products.page} '
                                'of ${data.products.totalPages}',
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Next page',
                              onPressed:
                                  data.products.page < data.products.totalPages
                                  ? () => _goToPage(data.products.page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
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
