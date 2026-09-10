import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../features/auth/data/services/auth_service.dart';
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
