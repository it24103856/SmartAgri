import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../data/models/farmer_product_models.dart';
import '../../data/services/farmer_product_service.dart';
import 'farmer_product_form_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  late Future<FarmerProductPage> _future;

  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<FarmerProductPage> _fetch() {
    return FarmerProductService.instance.list(page: _page, pageSize: _pageSize);
  }

  void _load({int page = 1}) {
    if (!mounted) return;

    setState(() {
      _page = page;
      _future = _fetch();
    });
  }

  Future<void> _refresh() async {
    _load(page: _page);

    try {
      await _future;
    } catch (_) {
      // FutureBuilder shows the error state.
    }
  }

  Future<void> _openForm({FarmerProduct? product}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FarmerProductFormScreen(product: product),
      ),
    );

    if (saved == true) {
      _load(page: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<FarmerProductPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _MessageView(
                  error: snapshot.error,
                  onRetry: () => _load(page: _page),
                );
              }

              final data = snapshot.data!;

              if (data.items.isEmpty) {
                return _MessageView(
                  message: 'You have not added any products yet.',
                  onRetry: () => _openForm(),
                  retryLabel: 'Add your first product',
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  ...data.items.map(
                    (product) => _ProductTile(
                      product: product,
                      onTap: () => _openForm(product: product),
                    ),
                  ),
                  if (data.totalPages > 1)
                    _Pagination(
                      page: data.page,
                      totalPages: data.totalPages,
                      onPrevious: data.page > 1
                          ? () => _load(page: data.page - 1)
                          : null,
                      onNext: data.page < data.totalPages
                          ? () => _load(page: data.page + 1)
                          : null,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final FarmerProduct product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CatalogImage(product.thumbnail),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusChip(status: product.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.categoryName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Stock: ${product.stockQuantity}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (product.isRejected &&
                        (product.rejectionReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Admin note: ${product.rejectionReason}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _Pagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Pagination({
    required this.page,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Page $page of $totalPages',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final Object? error;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const _MessageView({
    this.error,
    this.message = 'Something went wrong. Please try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    final problem = error;
    final needsLogin =
        problem is FarmerProductException && problem.needsLogin;

    final displayMessage = problem is FarmerProductException
        ? problem.message
        : problem != null
        ? 'Something went wrong. Please try again.'
        : message;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        Icon(
          problem == null ? Icons.inventory_2_outlined : Icons.cloud_off_outlined,
          color: AppColors.primary,
          size: 42,
        ),
        const SizedBox(height: 14),
        Text(
          displayMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        if (!needsLogin && onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(retryLabel),
            ),
          ),
        ],
      ],
    );
  }
}
