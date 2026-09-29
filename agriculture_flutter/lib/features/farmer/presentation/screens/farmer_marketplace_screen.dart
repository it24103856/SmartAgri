import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../../products/data/services/catalog_service.dart';
import '../widgets/farmer_ui.dart';

class FarmerMarketplaceScreen extends StatefulWidget {
  final String initialSearch;
  const FarmerMarketplaceScreen({super.key, this.initialSearch = ''});
  @override
  State<FarmerMarketplaceScreen> createState() =>
      _FarmerMarketplaceScreenState();
}

class _FarmerMarketplaceScreenState extends State<FarmerMarketplaceScreen> {
  late Future<CatalogData> _future = _fetch();
  late final _search = TextEditingController(text: widget.initialSearch);
  int _page = 1;
  late String _query = widget.initialSearch;
  Future<CatalogData> _fetch() =>
      CatalogService.instance.load(pageSize: 20, page: _page, search: _query);
  Future<void> _load({int? page}) async {
    setState(() {
      if (page != null) _page = page;
      _future = _fetch();
    });
    try {
      await _future;
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FarmerPage(
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: AppColors.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const FarmerHero(
              eyebrow: 'Grown by the community',
              title: 'Fresh finds.\nCloser to home.',
              subtitle:
                  'Explore produce and products from the SmartAgri marketplace.',
              icon: Icons.storefront_outlined,
            ),
            const FarmerSection('Discover products'),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _query = value;
                _load(page: 1);
              },
              decoration: InputDecoration(
                hintText: 'Search the marketplace',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search products',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    _query = _search.text;
                    _load(page: 1);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<CatalogData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return FarmerEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load the marketplace',
                    message: snapshot.error is CatalogException
                        ? (snapshot.error as CatalogException).message
                        : 'Please try again.',
                    onAction: _load,
                  );
                }
                final data = snapshot.data!.products;
                if (data.items.isEmpty) {
                  return FarmerEmpty(
                    icon: Icons.search_off,
                    title: 'No products found',
                    message:
                        'Try another search or check back for new produce.',
                    actionLabel: 'View all products',
                    onAction: () {
                      _search.clear();
                      _query = '';
                      _load(page: 1);
                    },
                  );
                }
                return Column(
                  children: [
                    ...data.items.map(
                      (product) => _ProductCard(product: product),
                    ),
                    if (data.totalPages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Previous page',
                            onPressed: data.page > 1
                                ? () => _load(page: data.page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page ${data.page} of ${data.totalPages}'),
                          IconButton(
                            tooltip: 'Next page',
                            onPressed: data.page < data.totalPages
                                ? () => _load(page: data.page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProductCard extends StatelessWidget {
  final CatalogProduct product;
  const _ProductCard({required this.product});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 96,
            height: 110,
            child: CatalogImage(product.thumbnail),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.categoryName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                product.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rs. ${product.price.toStringAsFixed(2)} / ${product.unit}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.inStock ? 'In stock' : 'Out of stock',
                style: TextStyle(
                  color: product.inStock ? AppColors.primary : AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
