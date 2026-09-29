import 'package:flutter/material.dart';

import 'glass_animated_nav_bar.dart';

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
  Widget build(BuildContext context) => GlassAnimatedNavBar(
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    onCreate: onCreate,
    isCreateMenuOpen: isCreateMenuOpen,
    icons: const [
      Icons.home_outlined,
      Icons.grid_view_rounded,
      Icons.shopping_cart_outlined,
      Icons.person_outline_rounded,
    ],
    labels: const ['Home', 'Products', 'Cart', 'Profile'],
  );
}
