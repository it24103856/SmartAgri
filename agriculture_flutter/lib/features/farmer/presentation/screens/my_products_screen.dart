import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../data/models/farmer_product_models.dart';
import '../../data/services/farmer_product_service.dart';
import '../widgets/farmer_ui.dart';
import 'farmer_product_form_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});
  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  late Future<List<FarmerProduct>> _future = FarmerProductService.instance
      .listAll();
  final _search = TextEditingController();
  String _status = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = FarmerProductService.instance.listAll());
    try {
      await _future;
    } catch (_) {
      /* Displayed in the list. */
    }
  }

  Future<void> _openForm({FarmerProduct? product}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FarmerProductFormScreen(product: product),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => FarmerPage(
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: AppColors.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<FarmerProduct>>(
          future: _future,
          builder: (context, snapshot) {
            final all = snapshot.data ?? <FarmerProduct>[];
            final query = _search.text.trim().toLowerCase();
            final filtered = all
                .where(
                  (p) =>
                      (_status == 'ALL' || p.status == _status) &&
                      '${p.name} ${p.categoryName}'.toLowerCase().contains(
                        query,
                      ),
                )
                .toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
              children: [
                const FarmerHero(
                  eyebrow: 'From farm to market',
                  title: 'Make your harvest stand out.',
                  subtitle:
                      'Manage your listings, keep stock up to date and follow each review.',
                  icon: Icons.inventory_2_outlined,
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  FarmerEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load products',
                    message: snapshot.error is FarmerProductException
                        ? (snapshot.error as FarmerProductException).message
                        : 'Please try again.',
                    onAction: _refresh,
                  )
                else ...[
                  const SizedBox(height: 16),
                  FarmerMetrics(
                    children: [
                      FarmerMetric(
                        value: '${all.length}',
                        label: 'Total products',
                        icon: Icons.inventory_2_outlined,
                      ),
                      FarmerMetric(
                        value: '${all.where((p) => p.isApproved).length}',
                        label: 'Approved',
                        icon: Icons.check_circle_outline,
                      ),
                      FarmerMetric(
                        value: '${all.where((p) => p.isPending).length}',
                        label: 'Awaiting review',
                        icon: Icons.schedule,
                      ),
                    ],
                  ),
                  const FarmerSection('Your listings'),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search products or categories',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(_search.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in const {
                        'ALL': 'All',
                        'APPROVED': 'Approved',
                        'PENDING': 'Pending',
                        'REJECTED': 'Rejected',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _status == entry.key,
                          onSelected: (_) =>
                              setState(() => _status = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (all.isEmpty)
                    FarmerEmpty(
                      icon: Icons.eco_outlined,
                      title: 'Your next harvest starts here',
                      message:
                          'Add a product with photos, a price and available stock.',
                      actionLabel: 'Add your first product',
                      onAction: () => _openForm(),
                    )
                  else if (filtered.isEmpty)
                    FarmerEmpty(
                      icon: Icons.search_off,
                      title: 'No matching products',
                      message: 'Try another name or review status.',
                      actionLabel: 'Clear filters',
                      onAction: () => setState(() {
                        _search.clear();
                        _status = 'ALL';
                      }),
                    )
                  else
                    ...filtered.map(
                      (p) => _ProductTile(
                        product: p,
                        onTap: () => _openForm(product: p),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ProductTile extends StatelessWidget {
  final FarmerProduct product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 88,
                    height: 96,
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
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.formattedPrice,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(status: product.status),
                Text(
                  product.stockQuantity == 0
                      ? 'Out of stock'
                      : '${product.stockQuantity} in stock',
                  style: TextStyle(
                    color: product.stockQuantity == 0
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (product.isRejected &&
                (product.rejectionReason ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Review note: ${product.rejectionReason}',
                  style: const TextStyle(color: AppColors.error, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  product.isRejected ? 'Edit & resubmit' : 'Edit product',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'APPROVED' => ('Approved', const Color(0xFF2E7D46)),
      'REJECTED' => ('Rejected', AppColors.error),
      _ => ('Pending review', const Color(0xFFB8860B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
