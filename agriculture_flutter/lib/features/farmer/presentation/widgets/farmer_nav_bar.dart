import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_animated_nav_bar.dart';

class FarmerNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FarmerNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 5);

  @override
  Widget build(BuildContext context) => GlassAnimatedNavBar(
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    icons: const [
      Icons.home_outlined,
      Icons.landscape_outlined,
      Icons.local_shipping_outlined,
      Icons.inventory_2_outlined,
      Icons.person_outline_rounded,
    ],
    labels: const ['Home', 'My Farms', 'Packages', 'Products', 'Profile'],
  );
}
