import 'package:flutter/material.dart';

import '../../features/products/data/models/catalog_models.dart';
import '../../features/products/presentation/screens/product_details_screen.dart';
import 'catalog_common.dart';

export 'catalog_common.dart';

class CatalogGrid extends StatelessWidget {
  final List<CatalogProduct> products;
  final bool compact;

  const CatalogGrid({super.key, required this.products, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final minWidth = MediaQuery.textScalerOf(
          context,
        ).scale(compact ? 94 : 155);

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
              SizedBox(
                width: width,
                child: _ProductCard(product, compact: compact),
              ),
          ],
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final CatalogProduct product;

  final bool compact;
  const _ProductCard(this.product, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return GlassCatalogCard(
      padding: EdgeInsets.zero,
      radius: compact ? 18 : 22,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showCatalogProduct(context, product.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CatalogImage(product.thumbnail),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 9 : 12),
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
                      height:
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(compact ? 11 : 16) *
                          2.6,
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 16,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.formattedPrice,
                      style: TextStyle(
                        fontSize: compact ? 12 : 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'per ${product.unit}',
                      style: TextStyle(
                        fontSize: compact ? 9 : 12,
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
      ),
    );
  }
}

Future<void> showCatalogProduct(BuildContext context, int id) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/products/$id'),
      builder: (_) => ProductDetailsScreen(productId: id),
    ),
  );
}
