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
  int? _archivingId;
  int? _availabilityId;
  bool get _busy => _archivingId != null || _availabilityId != null;
  bool _stockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _future = FarmerProductService.instance.listAll();
    });
    try {
      await _future;
    } catch (_) {
      /* Displayed in the list. */
    }
  }

  Future<void> _openForm({FarmerProduct? product}) async {
    if (_busy) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FarmerProductFormScreen(product: product),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _archive(FarmerProduct product) async {
    if (_busy || product.isArchived) return;

    setState(() => _archivingId = product.id);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Archive product?'),
          content: Text(
            '"${product.name}" will be hidden from the customer catalog.\n\n'
            'Existing orders will remain. You can edit and resubmit '
            'this product for approval later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep product'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;
      await FarmerProductService.instance.archive(product);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product archived.')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      if (error is FarmerProductException && error.statusCode == 409) {
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _archivingId = null);
    }
  }

  Future<void> _setAvailability(FarmerProduct product, bool active) async {
    if (_busy || product.isArchived) return;
    setState(() => _availabilityId = product.id);
    try {
      await FarmerProductService.instance.setAvailability(product, active);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? (product.isApproved
                      ? 'Product activated. Visible to customers.'
                      : 'Product activated. Admin approval is still required.')
                : 'Product deactivated. Hidden from customers.',
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      if (error is FarmerProductException && error.statusCode == 409) {
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _availabilityId = null);
    }
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
            final filtered = all.where((product) {
              final matchesStatus =
                  _status == 'ALL' || product.status == _status;

              final matchesSearch = '${product.name} ${product.categoryName}'
                  .toLowerCase()
                  .contains(query);

              final matchesStock = !_stockOnly || product.needsRestock;

              return matchesStatus && matchesSearch && matchesStock;
            }).toList();
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
                        'ARCHIVED': 'Archived',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _status == entry.key,
                          onSelected: (_) =>
                              setState(() => _status = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: Text(
                      'Low / no stock (${all.where((p) => p.needsRestock).length})',
                    ),
                    selected: _stockOnly,
                    onSelected: (selected) {
                      setState(() {
                        _stockOnly = selected;
                        if (selected) _status = 'ALL';
                      });
                    },
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
                        _stockOnly = false;
                      }),
                    )
                  else
                    ...filtered.map(
                      (p) => _ProductTile(
                        product: p,
                        busy: _busy,
                        changingAvailability: _availabilityId == p.id,
                        archiving: _archivingId == p.id,
                        onTap: () => _openForm(product: p),
                        onArchive: () => _archive(p),
                        onAvailabilityChanged: (active) =>
                            _setAvailability(p, active),
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
  final VoidCallback onArchive;
  final bool busy;
  final bool archiving;
  final bool changingAvailability;
  final ValueChanged<bool> onAvailabilityChanged;

  const _ProductTile({
    required this.product,
    required this.onTap,
    required this.onArchive,
    required this.busy,
    required this.archiving,
    required this.changingAvailability,
    required this.onAvailabilityChanged,
  });

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
      onTap: busy ? null : onTap,
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
                _StockChip(product: product),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onTap,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    product.isRejected || product.isArchived
                        ? 'Edit & resubmit'
                        : 'Edit product',
                  ),
                ),
                if (!product.isArchived)
                  TextButton.icon(
                    onPressed: busy ? null : onArchive,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    icon: archiving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.archive_outlined, size: 18),
                    label: Text(archiving ? 'Archiving...' : 'Archive'),
                  ),
              ],
            ),
            if (!product.isArchived)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(product.isActive ? 'Active' : 'Inactive'),
                subtitle: Text(
                  changingAvailability
                      ? 'Updating availability...'
                      : !product.isActive
                      ? 'Hidden from customers'
                      : product.isApproved
                      ? 'Visible to customers'
                      : 'Visible after admin approval',
                ),
                value: product.isActive,
                onChanged: busy ? null : onAvailabilityChanged,
              ),
            if (product.isArchived)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Hidden from customers. Edit and resubmit to request approval.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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
      'ARCHIVED' => ('Archived', const Color(0xFF607D8B)),
      'PENDING' => ('Pending review', const Color(0xFFB8860B)),
      _ => (status, AppColors.textSecondary),
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

class _StockChip extends StatelessWidget {
  final FarmerProduct product;

  const _StockChip({required this.product});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;

    if (product.isArchived) {
      color = const Color(0xFF607D8B);
      label = '${product.stockQuantity} units • Archived';
      icon = Icons.archive_outlined;
    } else if (product.isOutOfStock) {
      color = AppColors.error;
      label = 'Out of stock';
      icon = Icons.remove_shopping_cart_outlined;
    } else if (product.isLowStock) {
      color = const Color(0xFFAD5700);
      label = 'Low stock: ${product.stockQuantity} left';
      icon = Icons.warning_amber_rounded;
    } else {
      color = const Color(0xFF2E7D46);
      label = '${product.stockQuantity} in stock';
      icon = Icons.inventory_2_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
