import 'dart:math' as math;

import 'package:flutter/material.dart';

class CustomerNavigation extends InheritedWidget {
  final ValueChanged<int> selectTab;
  final void Function(int? categoryId, String search) openProducts;

  const CustomerNavigation({
    super.key,
    required this.selectTab,
    required this.openProducts,
    required super.child,
  });

  static CustomerNavigation? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CustomerNavigation>();
  }

  @override
  bool updateShouldNotify(CustomerNavigation oldWidget) {
    return selectTab != oldWidget.selectTab ||
        openProducts != oldWidget.openProducts;
  }
}

class CustomerAnimatedNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CustomerAnimatedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 4);

  static const _icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.shopping_cart_outlined,
    Icons.person_outline_rounded,
  ];

  static const _labels = ['Home', 'Products', 'Cart', 'Profile'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final barColor = Color.alphaBlend(
      Colors.green.withValues(alpha: 0.18),
      colors.primaryContainer,
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SizedBox(
        height: 82,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = (constraints.maxWidth - 40) / 4;

            final circleSize = math.min(42.0, slotWidth - 10);

            return TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: selectedIndex.toDouble(),
                end: selectedIndex.toDouble(),
              ),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, position, child) {
                final centerX = 20 + slotWidth * (position + 0.5);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _NavigationBarPainter(
                          centerX: centerX,
                          notchHalfWidth: math.min(32.0, slotWidth / 2),
                          backgroundColor: barColor,
                          borderColor: colors.outlineVariant,
                          shadowColor: colors.shadow.withValues(alpha: 0.09),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      left: 20,
                      right: 20,
                      child: Row(
                        textDirection: TextDirection.ltr,
                        children: List.generate(4, (index) {
                          final selected = index == selectedIndex;

                          return Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: _labels[index],
                              child: ExcludeSemantics(
                                child: Tooltip(
                                  message: _labels[index],
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => onSelected(index),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Positioned(
                                            top: 35,
                                            left: 0,
                                            right: 0,
                                            child: Opacity(
                                              opacity: selected ? 0 : 1,
                                              child: Icon(
                                                _icons[index],
                                                size: 22,
                                                color: colors.onSurfaceVariant,
                                              ),
                                            ),
                                          ),

                                          Positioned(
                                            left: 3,
                                            right: 3,
                                            bottom: 9,
                                            height: 16,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                _labels[index],
                                                style: TextStyle(
                                                  color: selected
                                                      ? colors.primary
                                                      : colors.onSurfaceVariant,
                                                  fontSize: 11,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    Positioned(
                      left: centerX - circleSize / 2,
                      top: 21 - circleSize / 2,
                      child: IgnorePointer(
                        child: Container(
                          width: circleSize,
                          height: circleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 150),
                            child: Icon(
                              _icons[selectedIndex],
                              key: ValueKey(selectedIndex),
                              size: 23,
                              color: colors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NavigationBarPainter extends CustomPainter {
  final double centerX;
  final double notchHalfWidth;

  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  const _NavigationBarPainter({
    required this.centerX,
    required this.notchHalfWidth,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    const radius = 16.0;
    const notchBottom = 49.0;

    final path = Path()
      ..moveTo(radius, top)
      ..lineTo(centerX - notchHalfWidth, top)
      ..cubicTo(
        centerX - notchHalfWidth * 0.68,
        top,
        centerX - notchHalfWidth * 0.8,
        notchBottom,
        centerX,
        notchBottom,
      )
      ..cubicTo(
        centerX + notchHalfWidth * 0.8,
        notchBottom,
        centerX + notchHalfWidth * 0.68,
        top,
        centerX + notchHalfWidth,
        top,
      )
      ..lineTo(size.width - radius, top)
      ..quadraticBezierTo(size.width, top, size.width, top + radius)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, top + radius)
      ..quadraticBezierTo(0, top, radius, top)
      ..close();

    canvas.drawShadow(path, shadowColor, 4, true);

    canvas.drawPath(path, Paint()..color = backgroundColor);

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_NavigationBarPainter oldDelegate) {
    return centerX != oldDelegate.centerX ||
        notchHalfWidth != oldDelegate.notchHalfWidth ||
        backgroundColor != oldDelegate.backgroundColor ||
        borderColor != oldDelegate.borderColor ||
        shadowColor != oldDelegate.shadowColor;
  }
}
