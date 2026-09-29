import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../data/models/package_models.dart';

class PackageCoverImage extends StatelessWidget {
  final Package package;
  final String? image;
  const PackageCoverImage({super.key, required this.package, this.image});

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFFE9EBCF),
      child: Center(
        child: Icon(
          package.isTransport
              ? Icons.local_shipping_rounded
              : package.isInputs
              ? Icons.spa_rounded
              : Icons.agriculture_rounded,
          size: 36,
          color: AppColors.primary,
        ),
      ),
    );
    final url = CatalogImage(image ?? package.thumbnail).url;
    if (url == null) return fallback;
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      semanticLabel: package.name,
      errorBuilder: (_, error, stackTrace) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

class PackageImageGallery extends StatefulWidget {
  final Package package;
  const PackageImageGallery({super.key, required this.package});

  @override
  State<PackageImageGallery> createState() => _PackageImageGalleryState();
}

class _PackageImageGalleryState extends State<PackageImageGallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 220,
          child: PageView.builder(
            itemCount: widget.package.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (_, index) => PackageCoverImage(
              package: widget.package,
              image: widget.package.images[index],
            ),
          ),
        ),
      ),
      if (widget.package.images.length > 1) ...[
        const SizedBox(height: 10),
        Text(
          '${_index + 1} / ${widget.package.images.length} photos · Swipe to explore',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ],
  );
}
