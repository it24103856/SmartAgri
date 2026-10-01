import 'package:flutter/material.dart';

import 'widgets/farmer_nav_bar.dart';
import 'widgets/farmer_glass.dart';
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
  late String _fullName;

  @override
  void initState() {
    super.initState();
    _fullName = widget.fullName;
  }

  Widget _page() => switch (_selectedIndex) {
    0 => FarmerDashboardScreen(fullName: _fullName, onOpenTab: _selectTab),
    1 => const MyFarmsScreen(),
    2 => const PackagesScreen(),
    3 => const MyProductsScreen(),
    _ => FarmerProfileScreen(
      fullName: _fullName,
      onUpdated: (user) {
        if (!mounted || _fullName == user.fullName) return;

        setState(() {
          _fullName = user.fullName;
        });
      },
    ),
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
      child: FarmerGlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _page(),
          bottomNavigationBar: FarmerNavBar(
            selectedIndex: _selectedIndex,
            onSelected: _selectTab,
          ),
        ),
      ),
    );
  }
}
