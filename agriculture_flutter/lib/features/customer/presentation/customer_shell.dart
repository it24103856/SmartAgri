import 'package:flutter/material.dart';

import '../../../shared/widgets/customer_animated_nav_bar.dart';
import '../../../shared/widgets/customer_create_menu.dart';
import '../../cart/presentation/cart_screen.dart';
import '../../smart_basket/presentation/smart_basket_screen.dart';
import '../../auth/data/models/user_model.dart';
import '../../profile/data/customer_profile_service.dart';
import '../../profile/presentation/customer_profile_screen.dart';
import '../../products/presentation/screens/customer_home_screen.dart';
import '../../products/presentation/screens/products_screen.dart';

class CustomerShell extends StatefulWidget {
  final String fullName;

  const CustomerShell({super.key, required this.fullName});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _selectedIndex = 0;
  final _draft = CustomerDraft();
  bool _creating = false;
  bool _createMenuOpen = false;

  Future<void> _openCreate() async {
    if (_creating) return;
    _creating = true;
    setState(() => _createMenuOpen = true);
    try {
      final action = await showCustomerCreateMenu(context);
      if (!mounted) return;
      setState(() => _createMenuOpen = false);
      if (action == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CustomerComposerScreen(
            draft: _draft,
            openCamera: action == CustomerCreateAction.camera,
          ),
        ),
      );
    } finally {
      _creating = false;
      if (mounted && _createMenuOpen) setState(() => _createMenuOpen = false);
    }
  }

  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();

    // Other tabs are created when first opened.
    _pages = [CustomerHomeScreen(fullName: widget.fullName), null, null, null];
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await CustomerProfileService.instance.load();
      _profileUpdated(user);
    } catch (_) {
      // Keep the home page and default account icon available when offline.
    }
  }

  void _profileUpdated(UserModel user) {
    if (!mounted) return;

    setState(() {
      _pages[0] = CustomerHomeScreen(
        fullName: user.fullName,
        profileImageUrl: user.profileImageUrl,
      );
    });
  }

  void _selectTab(int index) {
    if (!mounted || index == _selectedIndex) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      if (index == 1) {
        // Keep product filters and scrolling when switching tabs.
        _pages[1] ??= const ProductsScreen();
      } else if (index == 2) {
        // Reload cart data whenever the customer enters this tab.
        _pages[2] = CartScreen(key: UniqueKey());
      } else if (index == 3) {
        _pages[3] = CustomerProfileScreen(
          key: UniqueKey(),
          onUpdated: _profileUpdated,
        );
      }

      _selectedIndex = index;
    });
  }

  void _openProducts(int? categoryId, String search) {
    if (!mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      // A new search/category starts a fresh product listing.
      _pages[1] = ProductsScreen(
        key: UniqueKey(),
        initialCategoryId: categoryId,
        initialSearch: search,
      );

      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return CustomerNavigation(
      selectTab: _selectTab,
      openProducts: _openProducts,
      child: PopScope<Object?>(
        canPop: _selectedIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _selectedIndex != 0) {
            _selectTab(0);
          }
        },
        child: Scaffold(
          // Each existing screen handles its own keyboard resizing.
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: _selectedIndex,
            children: List.generate(
              _pages.length,
              (index) => TickerMode(
                enabled: index == _selectedIndex,
                child: _pages[index] ?? const SizedBox.shrink(),
              ),
            ),
          ),
          floatingActionButton:
              keyboardOpen || _selectedIndex != 0 || _createMenuOpen
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'customer-smart-basket',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SmartBasketScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Smart Basket'),
                ),
          bottomNavigationBar: keyboardOpen
              ? null
              : CustomerAnimatedNavBar(
                  selectedIndex: _selectedIndex,
                  onSelected: _selectTab,
                  onCreate: _openCreate,
                  isCreateMenuOpen: _createMenuOpen,
                ),
        ),
      ),
    );
  }
}
