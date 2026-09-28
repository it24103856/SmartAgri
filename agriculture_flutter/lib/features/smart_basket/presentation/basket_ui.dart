import 'package:flutter/material.dart';

import '../../../shared/widgets/catalog_common.dart';

export '../../../shared/widgets/catalog_common.dart' show GlassCatalogCard;

class BasketScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const BasketScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCatalogBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: actions,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class BasketHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  const BasketHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.icon = Icons.shopping_basket_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassCatalogCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eyebrow,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class BasketBadge extends StatelessWidget {
  final String status;
  final String label;
  const BasketBadge({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = status == 'Failed' || status == 'Rejected';
    final complete = status == 'Approved' || status == 'Ordered';
    final foreground = failed
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: failed ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed
                ? Icons.info_outline
                : complete
                ? Icons.check_circle_outline
                : Icons.schedule_rounded,
            size: 15,
            color: foreground,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
