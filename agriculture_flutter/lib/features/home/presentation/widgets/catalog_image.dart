import 'package:flutter/material.dart';

class CatalogImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const CatalogImage({super.key, this.url, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFF0F4E9),
      child: Center(
        child: Icon(Icons.eco_outlined, color: Color(0xFF638B3C), size: 36),
      ),
    );
    return url == null
        ? fallback
        : Image.network(
            url!,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : fallback,
          );
  }
}
