import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';

/// A day/night switch: swipe right for daylight, left for night.
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;
        void toggle() => ThemeController.toggle();

        return Semantics(
          label: 'Dark mode',
          toggled: isDark,
          onTap: toggle,
          child: ExcludeSemantics(
            child: Tooltip(
              message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              child: GestureDetector(
                onHorizontalDragStart: (_) => _dragDistance = 0,
                onHorizontalDragUpdate: (details) {
                  _dragDistance += details.delta.dx;
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  final direction = velocity.abs() > 200
                      ? velocity
                      : _dragDistance;
                  if (direction.abs() < 8) return;
                  ThemeController.mode.value = direction > 0
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
                onHorizontalDragCancel: () => _dragDistance = 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: toggle,
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 40,
                      height: 48,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: isDark ? 1 : 0,
                          end: isDark ? 1 : 0,
                        ),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 450),
                        curve: Curves.easeInOutCubic,
                        builder: (context, night, child) =>
                            CustomPaint(painter: _DayNightPainter(night)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DayNightPainter extends CustomPainter {
  final double night;

  const _DayNightPainter(this.night);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    const scale = 28 / 36;
    final trackWidth = size.width / scale;
    canvas.translate(0, (size.height - 36 * scale) / 2);
    canvas.scale(scale, scale);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, trackWidth, 36),
      const Radius.circular(18),
    );
    canvas.drawShadow(Path()..addRRect(track), Colors.black26, 3, true);
    canvas.clipRRect(track);
    final sky = Color.lerp(
      const Color(0xFFFFE58B),
      const Color(0xFF102F40),
      night,
    )!;
    canvas.drawRRect(track, Paint()..color = sky);

    // The sun and crescent sit opposite the sliding white thumb.
    final sun = Paint()
      ..color = const Color(0xFFFFF8DB).withValues(alpha: 1 - night);
    canvas.drawCircle(
      const Offset(16, 12),
      9,
      sun..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(const Offset(16, 12), 6, sun..maskFilter = null);
    final moon = Paint()..color = Colors.white.withValues(alpha: night);
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(const Rect.fromLTWH(51, 5, 15, 15)),
      Path()..addOval(const Rect.fromLTWH(47, 2, 15, 15)),
    );
    canvas.drawPath(crescent.shift(Offset(trackWidth - 76, 0)), moon);
    for (final star in const [
      Offset(34, 7),
      Offset(43, 12),
      Offset(48, 4),
      Offset(69, 15),
      Offset(37, 19),
    ]) {
      canvas.drawCircle(star, 0.65, moon);
    }

    void mountains(
      Color day,
      Color dark,
      double base,
      double amplitude,
      double phase,
    ) {
      final path = Path()
        ..moveTo(0, 36)
        ..lineTo(0, base);
      for (var x = 0.0; x <= trackWidth; x += trackWidth / 10) {
        path.lineTo(x, base + math.sin(x * 0.22 + phase) * amplitude);
      }
      path.lineTo(trackWidth, 36);
      path.close();
      canvas.drawPath(path, Paint()..color = Color.lerp(day, dark, night)!);
    }

    mountains(const Color(0xFFF6C44C), const Color(0xFF385969), 26, 4, 0);
    mountains(const Color(0xFFE5A22B), const Color(0xFF244655), 31, 3, 2);
    final center = Offset(trackWidth - 18 - (trackWidth - 36) * night, 18);
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: 15)),
      Colors.black26,
      2,
      true,
    );
    canvas.drawCircle(center, 15, Paint()..color = const Color(0xFFFAFAF7));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DayNightPainter oldDelegate) =>
      night != oldDelegate.night;
}
