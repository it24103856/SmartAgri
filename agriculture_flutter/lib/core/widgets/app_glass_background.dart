import 'package:flutter/material.dart';

/// Shared canvas for every route, including dialogs and nested tabs.
class AppGlassBackground extends StatelessWidget {
  final Widget child;
  const AppGlassBackground({super.key, required this.child});

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
              : const [Color(0xFFFFE6AD), Color(0xFFFFFBF2), Color(0xFFF0F3DD)],
          stops: const [0, 0.48, 1],
        ),
      ),
      child: child,
    );
  }
}
