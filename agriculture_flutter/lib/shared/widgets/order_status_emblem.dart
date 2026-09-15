import 'package:flutter/material.dart';

class OrderStatusEmblem extends StatelessWidget {
  final String status;

  const OrderStatusEmblem({super.key, required this.status});

  static Color colorFor(String status) => switch (status) {
    'Cancelled' || 'PaymentFailed' => const Color(0xFFC94343),
    'AwaitingPayment' || 'PaymentReview' => const Color(0xFFAC731B),
    _ => const Color(0xFF58A85D),
  };

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    final icon = switch (status) {
      'Cancelled' || 'PaymentFailed' => Icons.close_rounded,
      'AwaitingPayment' => Icons.hourglass_top_rounded,
      'PaymentReview' => Icons.priority_high_rounded,
      'Preparing' => Icons.inventory_2_outlined,
      'Packed' => Icons.all_inbox_outlined,
      'Dispatched' => Icons.local_shipping_outlined,
      'Confirmed' || 'Delivered' => Icons.check_rounded,
      _ => Icons.receipt_long_outlined,
    };

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 160,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: Stack(
            key: ValueKey(status),
            alignment: Alignment.center,
            children: [
              Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.07),
                ),
              ),
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Icon(icon, color: Colors.white, size: 46),
              ),
              for (final point in const [
                Alignment(-0.62, -0.64),
                Alignment(0.70, -0.54),
                Alignment(-0.45, 0.71),
                Alignment(0.60, 0.58),
              ])
                Align(
                  alignment: point,
                  child: Icon(Icons.auto_awesome, size: 14, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
