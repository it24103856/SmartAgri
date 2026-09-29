import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'farmer_ui.dart';

/// Warm surfaces used by the farmer overview and land collection.
class FarmerGlassBackground extends StatelessWidget {
  final Widget child;
  const FarmerGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFE6AD), Color(0xFFFFFBF2), Color(0xFFF0F3DD)],
        stops: [0, 0.48, 1],
      ),
    ),
    child: child,
  );
}

class FarmerGlassPage extends StatelessWidget {
  final Widget child;
  const FarmerGlassPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      FarmerGlassBackground(child: FarmerPage(child: child));
}

class FarmerGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const FarmerGlassCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8C713E).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                const Color(0xFFFFF5DB).withValues(alpha: 0.42),
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    ),
  );
}

class FarmerGlassHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? footer;
  const FarmerGlassHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.footer,
  });

  @override
  Widget build(BuildContext context) => FarmerGlassCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF77613C),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CircleAvatar(
              backgroundColor: const Color(0xFFFFE7AF),
              child: Icon(icon, color: const Color(0xFF826526)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            height: 1.15,
            letterSpacing: -1,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF746D5B), height: 1.5),
        ),
        if (footer != null) ...[const SizedBox(height: 20), footer!],
      ],
    ),
  );
}

class FarmerGlassMetric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const FarmerGlassMetric({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => FarmerGlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFFFEBC3),
          child: Icon(icon, size: 19, color: const Color(0xFF74602C)),
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF746D5B)),
        ),
      ],
    ),
  );
}

/// Existing artwork provides an offline illustration, never a farm photograph.
class FarmerLandscape extends StatelessWidget {
  const FarmerLandscape({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    width: double.infinity,
    child: Image.asset(
      'assets/images/plants_bg.jpg',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.25),
      excludeFromSemantics: true,
    ),
  );
}
