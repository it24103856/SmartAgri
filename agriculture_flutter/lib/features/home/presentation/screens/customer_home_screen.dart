import 'package:flutter/material.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../auth/data/services/profile_photo.dart';
import '../../data/catalog_service.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../widgets/customer_nav_bar.dart';
import '../widgets/catalog_image.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';

const _green = Color(0xFF5D8C39);
const _darkGreen = Color(0xFF294C29);
const _bg = Color(0xFFF6F8F2);

class CustomerHomeScreen extends StatefulWidget {
  final String fullName;
  final Future<ProfilePhoto?> Function()? pickPhoto;
  final Future<String> Function(ProfilePhoto)? uploadPhoto;
  final Future<CatalogData> Function()? loadCatalog;
  const CustomerHomeScreen({
    super.key,
    required this.fullName,
    this.loadCatalog,
    this.pickPhoto,
    this.uploadPhoto,
  });
  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  CatalogData? _catalog;
  String? _error;
  String? _profileImageUrl;
  bool _updatingPhoto = false;
  bool _loading = true, _expired = false;
  int _tab = 0;
  int? _categoryId;
  final _search = TextEditingController();
  final Map<int, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _expired = false;
    });
    try {
      final data = await (widget.loadCatalog ?? CatalogService.load)();
      if (!mounted) return;
      setState(() {
        _catalog = data;
        _profileImageUrl = data.profileImageUrl;
        if (!data.categories.any((c) => c.id == _categoryId)) {
          _categoryId = null;
        }
        // Reconcile the local basket with current availability on refresh.
        for (final id in _cart.keys.toList()) {
          final matches = data.products.where(
            (p) => p.id == id && p.stockQuantity > 0,
          );
          if (matches.isEmpty) {
            _cart.remove(id);
          } else {
            _cart[id] = _cart[id]!.clamp(0, matches.first.stockQuantity);
          }
        }
      });
    } on CatalogException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _expired = error.sessionExpired;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load the shop. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePhoto() async {
    setState(() => _updatingPhoto = true);
    try {
      final photo = await (widget.pickPhoto ?? ProfilePhoto.pick)();
      if (photo == null || !mounted) return;
      final url =
          await (widget.uploadPhoto ?? AuthService.instance.updateProfilePhoto)(
            photo,
          );
      if (mounted) {
        setState(() => _profileImageUrl = url);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthException
                  ? error.message
                  : 'Could not update your photo. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  int get _cartCount => _cart.values.fold(0, (sum, n) => sum + n);
  void _add(CatalogProduct product) {
    final count = _cart[product.id] ?? 0;
    if (count >= product.stockQuantity) return;
    setState(() => _cart[product.id] = count + 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: isDark ? const Color(0xFF101A15) : _bg,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        bottomNavigationBar: CustomerNavBar(
          selectedIndex: _tab,
          cartCount: _cartCount,
          onSelected: (index) => setState(() => _tab = index),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey('$_tab-$_loading-${_error != null}'),
                  child: _tab == 3
                      ? _profile()
                      : _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _green),
                        )
                      : _error != null
                      ? _failure()
                      : _tab == 2
                      ? _basket()
                      : _shop(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _failure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: _green,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 15),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _expired ? _logout : _load,
            child: Text(_expired ? 'Sign in again' : 'Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _shop() {
    final data = _catalog!;
    final query = _search.text.trim().toLowerCase();
    final products = data.products
        .where(
          (p) =>
              (_categoryId == null || p.categoryId == _categoryId) &&
              (query.isEmpty ||
                  p.name.toLowerCase().contains(query) ||
                  p.categoryName.toLowerCase().contains(query)),
        )
        .toList();
    final name = data.fullName.trim().isEmpty ? widget.fullName : data.fullName;
    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _tab = 3),
                child: ProfileAvatar(url: _profileImageUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tab == 0
                          ? 'Hi, ${name.trim().split(' ').first} 👋'
                          : 'Browse products',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2A17),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'What would you like to buy today?',
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const ThemeToggleButton(),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                shadowColor: Colors.black26,
                child: IconButton(
                  tooltip: 'Open cart',
                  onPressed: () => setState(() => _tab = 2),
                  icon: Badge(
                    isLabelVisible: _cartCount > 0,
                    backgroundColor: _darkGreen,
                    label: Text('$_cartCount'),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      color: _green,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search for products',
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.black45),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => setState(_search.clear),
                      icon: const Icon(Icons.close, color: Colors.black45),
                    ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _green, width: 1.5),
              ),
            ),
          ),
          if (_tab == 0) ...[const SizedBox(height: 20), _banner(data)],
          const SizedBox(height: 26),
          const Text(
            'Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2A17),
            ),
          ),
          const SizedBox(height: 12),
          if (data.categories.isEmpty)
            const Text(
              'Categories will appear here when available.',
              style: TextStyle(color: Colors.black45),
            )
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: data.categories.length + 1,
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final category = index == 0
                      ? null
                      : data.categories[index - 1];
                  final selected = _categoryId == category?.id;
                  return SizedBox(
                    width: 92,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      elevation: selected ? 2 : 0,
                      shadowColor: _green.withValues(alpha: 0.3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _categoryId = category?.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: selected
                                ? _green.withValues(alpha: 0.08)
                                : Colors.white,
                            border: Border.all(
                              color: selected
                                  ? _green
                                  : const Color(0xFFEFF1EA),
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: category == null
                                      ? Container(
                                          color: _green.withValues(alpha: 0.1),
                                          child: const Center(
                                            child: Icon(
                                              Icons.grid_view_rounded,
                                              color: _green,
                                              size: 28,
                                            ),
                                          ),
                                        )
                                      : CatalogImage(url: category.imageUrl),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                category?.name ?? 'All',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: selected ? _darkGreen : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryId != null || query.isNotEmpty
                      ? 'Matching products'
                      : 'Fresh from our catalog',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2A17),
                  ),
                ),
              ),
              if (_tab == 0)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: _green),
                  onPressed: () => setState(() {
                    _tab = 1;
                    _categoryId = null;
                    _search.clear();
                  }),
                  child: const Text(
                    'See all',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No products found. Try another category or search.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700
                    ? 4
                    : constraints.maxWidth >= 480
                    ? 3
                    : 2;
                final cardWidth =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: products
                      .map(
                        (p) => SizedBox(width: cardWidth, child: _product(p)),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _banner(CatalogData data) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: _darkGreen.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Fresh & Healthy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Discover your next fresh find.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _tab = 1;
                      _categoryId = null;
                      _search.clear();
                    }),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _darkGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text(
                      'Shop now',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: CatalogImage(
              url: data.products
                  .where((p) => p.imageUrl != null)
                  .firstOrNull
                  ?.imageUrl,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _product(CatalogProduct product) {
    final count = _cart[product.id] ?? 0;
    final outOfStock = product.stockQuantity == 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.15,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: const Color(0xFFF3F5EF),
                    child: CatalogImage(
                      url: product.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (outOfStock)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Out of stock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'LKR ${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _darkGreen,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${product.unit}',
                style: const TextStyle(color: Colors.black38, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                disabledBackgroundColor: const Color(0xFFE6E9E0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              onPressed: count >= product.stockQuantity
                  ? null
                  : () => _add(product),
              icon: Icon(
                count > 0 ? Icons.check : Icons.add,
                size: 16,
                color: outOfStock ? Colors.black38 : null,
              ),
              label: Text(
                outOfStock
                    ? 'Out of stock'
                    : count >= product.stockQuantity
                    ? 'Stock limit'
                    : count > 0
                    ? 'Added ($count)'
                    : 'Add',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _basket() {
    final products = _catalog!.products
        .where((p) => _cart.containsKey(p.id))
        .toList();
    final total = products.fold<double>(
      0,
      (sum, p) => sum + p.price * _cart[p.id]!,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      children: [
        const Text(
          'Your cart',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2A17),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your selections for this visit. Prices and stock may change.',
          style: TextStyle(color: Colors.black54, fontSize: 13.5),
        ),
        const SizedBox(height: 24),
        if (products.isEmpty) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 36,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Your cart is empty.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: _green),
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text(
                      'Browse products',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ...products.map(
          (p) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Container(
                          color: const Color(0xFFF3F5EF),
                          child: CatalogImage(url: p.imageUrl),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove ${p.name}',
                      onPressed: () => setState(() => _cart.remove(p.id)),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'LKR ${(p.price * _cart[p.id]!).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _darkGreen,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5EF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Decrease quantity',
                            iconSize: 20,
                            onPressed: () => setState(() {
                              if (_cart[p.id] == 1) {
                                _cart.remove(p.id);
                              } else {
                                _cart[p.id] = _cart[p.id]! - 1;
                              }
                            }),
                            icon: const Icon(Icons.remove, color: _green),
                          ),
                          Text(
                            '${_cart[p.id]}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            tooltip: 'Increase quantity',
                            iconSize: 20,
                            onPressed: _cart[p.id]! >= p.stockQuantity
                                ? null
                                : () => _add(p),
                            icon: const Icon(Icons.add, color: _green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (products.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _darkGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'LKR ${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ordering is not available yet.',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _profile() => ListView(
    padding: EdgeInsets.zero,
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_darkGreen, Color(0xFF3A6338)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          children: [
            ProfileAvatar(url: _profileImageUrl, radius: 42),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _updatingPhoto || _loading ? null : _changePhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _updatingPhoto ? 'Updating photo...' : 'Change profile photo',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _catalog?.fullName ?? widget.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Customer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(24),
        child: OutlinedButton.icon(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.logout),
          label: const Text(
            'Sign out',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ],
  );
}
