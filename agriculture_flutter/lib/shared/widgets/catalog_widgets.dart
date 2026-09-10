import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../features/auth/data/services/auth_service.dart';
import '../../features/products/data/models/catalog_models.dart';
import '../../features/products/data/services/catalog_service.dart';

Future<void> signOutCustomer(BuildContext context) async {
  await AuthService.instance.logout();

  if (!context.mounted) return;

  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}

class CatalogImage extends StatelessWidget {
  final String? path;

  const CatalogImage(this.path, {super.key});

  String? get url {
    final value = path?.trim();

    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);

    if (uri == null) return null;

    if (uri.hasScheme) {
      return ['http', 'https'].contains(uri.scheme) ? uri.toString() : null;
    }

    // /uploads/products/image.jpg resolves against the API server.
    return Uri.parse(
      ApiConstants.baseUrl,
    ).resolve('/${value.replaceFirst(RegExp(r'^/+'), '')}').toString();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(
        Icons.eco_outlined,
        size: 38,
        color: Theme.of(context).colorScheme.primary,
        semanticLabel: 'Product image unavailable',
      ),
    );

    final imageUrl = url;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: imageUrl == null
          ? fallback
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, error, stackTrace) => fallback,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;

                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
            ),
    );
  }
}

class CatalogMessage extends StatelessWidget {
  final Object? error;
  final String message;
  final VoidCallback? onRetry;

  const CatalogMessage({
    super.key,
    this.error,
    this.onRetry,
    this.message = 'No products to show yet.',
  });

  @override
  Widget build(BuildContext context) {
    final problem = error;
    final needsLogin = problem is CatalogException && problem.needsLogin;

    final displayMessage = problem is CatalogException
        ? problem.message
        : problem != null
        ? 'Something went wrong. Please try again.'
        : message;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            problem == null
                ? Icons.inventory_2_outlined
                : Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 42,
          ),
          const SizedBox(height: 14),
          Text(displayMessage, textAlign: TextAlign.center),
          if (needsLogin || onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: needsLogin ? () => signOutCustomer(context) : onRetry,
              child: Text(needsLogin ? 'Sign in again' : 'Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class CatalogGrid extends StatelessWidget {
  final List<CatalogProduct> products;

  const CatalogGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final minWidth = MediaQuery.textScalerOf(context).scale(155);

        final columns = ((bounds.maxWidth + 12) / (minWidth + 12))
            .floor()
            .clamp(1, 4)
            .toInt();

        final width = (bounds.maxWidth - 12 * (columns - 1)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final product in products)
              SizedBox(width: width, child: _ProductCard(product)),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final CatalogProduct product;

  const _ProductCard(this.product);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showCatalogProduct(context, product.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.15,
              child: CatalogImage(product.thumbnail),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(16) * 2.8,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.formattedPrice,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    'per ${product.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.inStock ? 'In stock' : 'Out of stock',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: product.inStock
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF97551F),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCatalogProduct(BuildContext context, int id) async {
  var future = CatalogService.instance.product(id);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, updateSheet) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Product details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<CatalogProduct>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return SingleChildScrollView(
                          child: CatalogMessage(
                            error: snapshot.error,
                            onRetry: () {
                              updateSheet(() {
                                future = CatalogService.instance.product(id);
                              });
                            },
                          ),
                        );
                      }

                      final p = snapshot.requireData;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: SizedBox(
                              height: 250,
                              child: p.images.isEmpty
                                  ? const CatalogImage(null)
                                  : PageView(
                                      children: [
                                        for (final path in p.images)
                                          CatalogImage(path),
                                      ],
                                    ),
                            ),
                          ),
                          if (p.images.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${p.images.length} photos · Swipe to view',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 22),
                          Text(
                            p.categoryName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Product #${p.id}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.formattedPrice,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text('Price per ${p.unit}'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  p.inStock
                                      ? '${p.stockQuantity} units available'
                                      : 'Out of stock',
                                ),
                              ),
                              if (p.weightKg != null)
                                Chip(label: Text('Weight: ${p.weightKg} kg')),
                            ],
                          ),
                          const Divider(height: 32),
                          const Text(
                            'About this product',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            p.description?.trim().isNotEmpty == true
                                ? p.description!
                                : 'No description has been added yet.',
                            style: const TextStyle(height: 1.6),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
