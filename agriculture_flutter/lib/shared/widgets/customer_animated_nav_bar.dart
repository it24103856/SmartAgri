import 'dart:ui' as ui;
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

/// ---------------------------------------------------------------------
/// GLASS SKIN PALETTE (green + white mix)
/// Only these constants control the look. Change them to retune the skin.
/// ---------------------------------------------------------------------
class _GlassPalette {
  // Core accent green used for the selected pill, selected icon/label, glow.
  static const Color accent = Color(0xFF22C55E); // vivid green
  static const Color accentDark = Color(0xFF16A34A); // deeper green (dark mode)

  // Tints mixed into the frosted glass background.
  static const Color glassTintDark = Color(0xFF14532D); // deep green tint

  // Base "glass" white used for the frosted look.
  static const Color glassWhite = Colors.white;

  static const Color unselected = Color(0xFF5B6B63); // muted green-gray
  static const Color unselectedDark = Color(0xFFB7C9BE);
}

class CustomerAnimatedNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCreate;
  final bool isCreateMenuOpen;

  const CustomerAnimatedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreate,
    this.isCreateMenuOpen = false,
  }) : assert(selectedIndex >= 0 && selectedIndex < 4);

  @override
  State<CustomerAnimatedNavBar> createState() => _CustomerAnimatedNavBarState();
}

class _CustomerAnimatedNavBarState extends State<CustomerAnimatedNavBar>
    with SingleTickerProviderStateMixin {
  // Change these values to resize the centre create button and selected tab.
  static const _createButtonSize = 34.0;
  static const _createIconSize = 20.0;
  static const _selectedButtonSize = 30.0;

  static const _icons = [
    Icons.home_outlined,
    Icons.grid_view_rounded,
    Icons.shopping_cart_outlined,
    Icons.person_outline_rounded,
  ];

  static const _labels = ['Home', 'Products', 'Cart', 'Profile'];

  late final AnimationController _controller;

  late double _fromPosition;
  late double _toPosition;

  double _fromLift = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();

    _fromPosition =
        (widget.selectedIndex < 2
                ? widget.selectedIndex
                : widget.selectedIndex + 1)
            .toDouble();
    _toPosition = _fromPosition;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
      value: 1,
    );
  }

  // First part: jump towards the selected tab.
  double get _travel {
    return (_controller.value / 0.72).clamp(0.0, 1.0).toDouble();
  }

  double get _position {
    final progress = Curves.easeInOutCubic.transform(_travel);

    return _fromPosition + (_toPosition - _fromPosition) * progress;
  }

  // Remaining part: a small bounce after landing.
  double get _landing {
    return ((_controller.value - 0.72) / 0.28).clamp(0.0, 1.0).toDouble();
  }

  double get _lift {
    if (_controller.value < 0.72) {
      return _fromLift * (1 - _travel) + math.sin(math.pi * _travel) * 22;
    }

    return math.sin(math.pi * _landing) * 5;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (_reduceMotion) {
      _controller.stop();
      _fromPosition =
          (widget.selectedIndex < 2
                  ? widget.selectedIndex
                  : widget.selectedIndex + 1)
              .toDouble();
      _toPosition = _fromPosition;
      _fromLift = 0;
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant CustomerAnimatedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedIndex == widget.selectedIndex) {
      return;
    }

    // Capture the current position for quick repeated taps.
    final currentPosition = _position;
    final currentLift = _lift;

    _controller.stop();

    _fromPosition = currentPosition;
    _fromLift = currentLift;
    _toPosition =
        (widget.selectedIndex < 2
                ? widget.selectedIndex
                : widget.selectedIndex + 1)
            .toDouble();

    if (_reduceMotion) {
      _fromPosition = _toPosition;
      _fromLift = 0;
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    // ---- GLASS SKIN COLORS (green + white mix) -------------------------
    final accent = dark
        ? const ui.Color.fromARGB(255, 23, 158, 72)
        : _GlassPalette.accent;
    final unselectedColor = dark
        ? _GlassPalette.unselectedDark
        : _GlassPalette.unselected;

    // Frosted glass background: white base + a soft green tint blended in.
    final barColor = Color.alphaBlend(
      (dark
              ? _GlassPalette.glassTintDark
              : const ui.Color.fromARGB(255, 146, 247, 181))
          .withValues(alpha: dark ? 0.30 : 0.38),
      _GlassPalette.glassWhite.withValues(alpha: dark ? 0.16 : 0.42),
    );

    // Thin bright edge so the glass reads as a distinct floating surface.
    final borderColor = Color.alphaBlend(
      accent.withValues(alpha: 0.36),
      Colors.white.withValues(alpha: dark ? 0.28 : 0.75),
    );

    // Soft green glow under the bar instead of the theme primary shadow.
    final shadowColor = accent.withValues(alpha: dark ? 0.22 : 0.18);
    // ---------------------------------------------------------------------

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SizedBox(
        height: 82,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = (constraints.maxWidth - 40) / 5;
            final circleSize = math.min(_selectedButtonSize, slotWidth - 10);

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final centerX = 20 + slotWidth * (_position + 0.5);
                final lift = _lift;

                final squash = math.sin(math.pi * _landing) * 0.10;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Builder(
                        builder: (context) {
                          final painter = _NavigationBarPainter(
                            centerX: centerX,
                            notchHalfWidth: widget.isCreateMenuOpen
                                ? 0
                                : math.min(32.0, slotWidth / 2),
                            backgroundColor: barColor,
                            borderColor: borderColor,
                            shadowColor: shadowColor,
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipPath(
                                clipper: _NavigationGlassClipper(painter),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: 18,
                                    sigmaY: 18,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              CustomPaint(painter: painter),
                            ],
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      left: 20,
                      right: 20,
                      child: Row(
                        textDirection: TextDirection.ltr,
                        children: List.generate(5, (slot) {
                          if (slot == 2) {
                            return Expanded(
                              child: Center(
                                child: IconButton.filled(
                                  tooltip: 'Create',
                                  onPressed: widget.onCreate,
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: _createIconSize,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(
                                      _createButtonSize,
                                      _createButtonSize,
                                    ),
                                    fixedSize: const Size(
                                      _createButtonSize,
                                      _createButtonSize,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            );
                          }
                          final index = slot < 2 ? slot : slot - 1;
                          final selected = index == widget.selectedIndex;

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
                                      onTap: () {
                                        if (!selected) {
                                          widget.onSelected(index);
                                        }
                                      },
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Positioned(
                                            top: 35,
                                            left: 0,
                                            right: 0,
                                            child: AnimatedOpacity(
                                              opacity:
                                                  selected &&
                                                      !widget.isCreateMenuOpen
                                                  ? 0
                                                  : 1,
                                              duration: _reduceMotion
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 120,
                                                    ),
                                              child: Icon(
                                                _icons[index],
                                                size: 22,
                                                color: unselectedColor,
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
                                                      ? accent
                                                      : unselectedColor,
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

                    if (!widget.isCreateMenuOpen)
                      Positioned(
                        key: const ValueKey('selected-tab-ball'),
                        left: centerX - circleSize / 2,
                        top: 21 - circleSize / 2 - lift,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                1 + squash,
                                1 - squash,
                                1,
                              ),
                              child: Container(
                                width: circleSize,
                                height: circleSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accent,
                                      dark
                                          ? _GlassPalette.accent
                                          : _GlassPalette.accentDark,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 8 + lift * 0.2,
                                      offset: Offset(0, 3 + lift * 0.12),
                                    ),
                                  ],
                                ),
                                child: AnimatedSwitcher(
                                  duration: _reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 160),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    _icons[widget.selectedIndex],
                                    key: ValueKey(widget.selectedIndex),
                                    size: 23,
                                    color: Colors.white,
                                  ),
                                ),
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

  Path outline(Size size) {
    const top = 18.0;
    const radius = 16.0;
    const notchBottom = 49.0;

    final path = Path()..moveTo(radius, top);
    if (notchHalfWidth > 0) {
      path
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
        );
    }
    path
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

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = outline(size);
    canvas.drawShadow(path, shadowColor, 6, true);

    // Frosted glass fill: base tinted color + a soft white highlight for
    // that classic top-left "glass shine".
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.35),
              backgroundColor,
            ),
            backgroundColor.withValues(alpha: backgroundColor.a * 0.55),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
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

class _NavigationGlassClipper extends CustomClipper<Path> {
  final _NavigationBarPainter painter;
  const _NavigationGlassClipper(this.painter);

  @override
  Path getClip(Size size) => painter.outline(size);

  @override
  bool shouldReclip(_NavigationGlassClipper oldClipper) =>
      painter.centerX != oldClipper.painter.centerX ||
      painter.notchHalfWidth != oldClipper.painter.notchHalfWidth;
}
