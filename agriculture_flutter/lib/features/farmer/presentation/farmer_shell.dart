import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'screens/farmer_dashboard_screen.dart';
import 'screens/my_farms_screen.dart';
import 'screens/my_products_screen.dart';
import 'screens/packages_screen.dart';
import 'screens/farmer_profile_screen.dart';

class FarmerShell extends StatefulWidget {
  final String fullName;

  const FarmerShell({super.key, required this.fullName});

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int _selectedIndex = 0;

  Widget _page() => switch (_selectedIndex) {
    0 => FarmerDashboardScreen(
      fullName: widget.fullName,
      onOpenTab: _selectTab,
    ),
    1 => const MyFarmsScreen(),
    2 => const PackagesScreen(),
    3 => const MyProductsScreen(),
    _ => FarmerProfileScreen(fullName: widget.fullName),
  };

  void _selectTab(int index) {
    if (!mounted || index == _selectedIndex) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        body: _page(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.soft,
          height: 76,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.landscape_outlined),
              selectedIcon: Icon(Icons.landscape, color: AppColors.primary),
              label: 'My Farms',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(
                Icons.local_shipping,
                color: AppColors.primary,
              ),
              label: 'Packages',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
              label: 'Products',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
