import 'package:flutter/material.dart';

class CustomerNavBar extends StatelessWidget {
  final int selectedIndex;
  final int cartCount;
  final ValueChanged<int> onSelected;
  const CustomerNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.cartCount = 0,
  });

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: onSelected,
    backgroundColor: Colors.white,
    indicatorColor: const Color(0xFFE6EEDB),
    destinations: [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        label: 'Browse',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          child: const Icon(Icons.shopping_cart_outlined),
        ),
        label: 'Cart',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        label: 'Profile',
      ),
    ],
  );
}
