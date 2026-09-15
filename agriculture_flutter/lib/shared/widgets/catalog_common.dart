import 'dart:ui' as ui;

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

/// Soft mint and cream canvas used by the shopping detail views.
class GlassCatalogBackground extends StatelessWidget {
  final Widget child;
  const GlassCatalogBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF152E27), Color(0xFF15231F), Color(0xFF24251E)]
              : const [Color(0xFFD5EDE2), Color(0xFFF5F4E9), Color(0xFFFFEAD8)],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: child,
    );
  }
}

/// Clipped blur keeps the glass effect inside each shopping card.
class GlassCatalogCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const GlassCatalogCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : const Color(0xFF527969)).withValues(
              alpha: dark ? 0.18 : 0.09,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface.withValues(alpha: dark ? 0.72 : 0.64),
                  colors.surface.withValues(alpha: dark ? 0.42 : 0.28),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? 0.13 : 0.8),
                width: 1.2,
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
