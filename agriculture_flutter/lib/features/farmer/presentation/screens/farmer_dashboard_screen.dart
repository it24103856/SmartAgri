import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/catalog_common.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../../products/data/services/catalog_service.dart';
import '../../data/models/package_models.dart';
import '../../data/services/package_service.dart';
import '../widgets/farmer_glass.dart';
import '../widgets/package_images.dart';
import 'farmer_marketplace_screen.dart';
import 'packages_screen.dart';

class FarmerDashboardScreen extends StatefulWidget {
  final String fullName;
  final ValueChanged<int> onOpenTab;
  const FarmerDashboardScreen({
    super.key,
    required this.fullName,
    required this.onOpenTab,
  });

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  final _search = TextEditingController();
  late Future<List<Package>> _packages;
  late Future<CatalogData> _catalog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _packages = PackageService.instance.list();
    // Public marketplace: never use the signed-in farmer's inventory here.
    _catalog = CatalogService.instance.load(pageSize: 8, sort: 'latest');
    _packages.ignore();
    _catalog.ignore();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _packages.then<void>((_) {}, onError: (Object _) {}),
      _catalog.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openMarketplace({String search = ''}) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FarmerMarketplaceScreen(initialSearch: search),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.fullName.trim();
    final firstName = name.isEmpty
        ? 'Farmer'
        : name.split(RegExp(r'\s+')).first;
    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: ClipOval(
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  semanticLabel: 'AgriLink logo',
                ),
              ),
            ),
          ),
          title: const Text(
            'AgriLink',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh overview',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Your profile',
              onPressed: () => widget.onOpenTab(4),
              icon: const Icon(Icons.account_circle_outlined, size: 29),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'Hello, $firstName \u{1F44B}',
                style: const TextStyle(fontSize: 15, color: Color(0xFF74765D)),
              ),
              const SizedBox(height: 16),
              FarmerGlassCard(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _openMarketplace(search: value),
                  decoration: InputDecoration(
                    hintText: 'Search fresh products...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF85846E),
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Search marketplace',
                      onPressed: () => _openMarketplace(search: _search.text),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _hero(),
              const SizedBox(height: 16),
              _heading(
                'Farm packages',
                () => widget.onOpenTab(2),
                'See all packages',
              ),
              const SizedBox(height: 8),
              _packageSection(),
              const SizedBox(height: 18),
              _heading(
                'Latest products',
                () => _openMarketplace(),
                'See all products',
              ),
              const Text(
                'Fresh finds from all growers',
                style: TextStyle(fontSize: 12, color: Color(0xFF81816B)),
              ),
              const SizedBox(height: 14),
              _productSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, VoidCallback onTap, String tooltip) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      TextButton(
        onPressed: onTap,
        child: Semantics(
          label: tooltip,
          excludeSemantics: true,
          child: const Text('See all', style: TextStyle(fontSize: 12)),
        ),
      ),
    ],
  );

  Widget _hero() => FarmerGlassCard(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF2DFB0), Color(0xFFFFF9EB)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final copy = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ROOTED IN POSSIBILITY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF87723F),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Good land.\nGreat beginnings.',
                  style: TextStyle(
                    fontSize: 23,
                    height: 1.12,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Everything for your\nnext harvest.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF7D7A60),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => widget.onOpenTab(1),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('My farms', style: TextStyle(fontSize: 12)),
                ),
              ],
            );
            final artwork = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/farmer_dashboard_hero.jpg',
                fit: BoxFit.contain,
                semanticLabel: 'Farm and harvest artwork',
                errorBuilder: (_, error, stack) => const Center(
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 48,
                    color: AppColors.primary,
                    semanticLabel: 'Farm artwork unavailable',
                  ),
                ),
              ),
            );
            if (bounds.maxWidth < 270 ||
                MediaQuery.textScalerOf(context).scale(14) > 20) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  copy,
                  const SizedBox(height: 16),
                  SizedBox(height: 220, width: double.infinity, child: artwork),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 5, child: copy),
                const SizedBox(width: 8),
                Expanded(flex: 7, child: SizedBox(height: 240, child: artwork)),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _packageSection() => FutureBuilder<List<Package>>(
    future: _packages,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _SectionLoading(label: 'Loading packages');
      }
      if (snapshot.hasError) {
        return _message(
          'Packages are unavailable right now.',
          retry: () => setState(() {
            _packages = PackageService.instance.list();
            _packages.ignore();
          }),
        );
      }
      final packages = snapshot.data!.where((p) => p.isActive).toList();
      if (packages.isEmpty) {
        return _message('New farm packages will appear here.');
      }
      return LayoutBuilder(
        builder: (context, bounds) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
          final columns = largeText
              ? 2
              : (bounds.maxWidth / 92).floor().clamp(2, 6);
          final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 14,
            children: [
              for (final package in packages.take(6))
                SizedBox(
                  width: width,
                  child: Semantics(
                    button: true,
                    label: 'View ${package.name}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => showFarmerPackageBooking(context, package),
                      child: Column(
                        children: [
                          FarmerGlassCard(
                            padding: const EdgeInsets.all(10),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PackageCoverImage(package: package),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            package.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );

  Widget _productSection() => FutureBuilder<CatalogData>(
    future: _catalog,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _SectionLoading(label: 'Loading products');
      }
      if (snapshot.hasError) {
        return _message(
          'Could not load marketplace products.',
          retry: () => setState(() {
            _catalog = CatalogService.instance.load(
              pageSize: 8,
              sort: 'latest',
            );
            _catalog.ignore();
          }),
        );
      }
      final products = snapshot.data!.products.items;
      if (products.isEmpty) {
        return _message('No marketplace products are available yet.');
      }
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      return SizedBox(
        height: 160 + 118 * scale,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final product = products[index];
            return SizedBox(
              width: 164,
              child: FarmerGlassCard(
                child: InkWell(
                  onTap: () => _showProduct(product),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            height: 128,
                            width: double.infinity,
                            child: CatalogImage(product.thumbnail),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          product.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF83846E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          product.formattedPrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'per ${product.unit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF83846E),
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  void _showProduct(CatalogProduct product) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFFFF9ED),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 230,
              child: CatalogImage(product.thumbnail),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            product.categoryName,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${product.formattedPrice} / ${product.unit}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.inStock ? 'In stock' : 'Out of stock',
            style: TextStyle(
              color: product.inStock ? AppColors.primary : AppColors.error,
            ),
          ),
          if (product.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 18),
            Text(
              product.description!,
              style: const TextStyle(
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _message(String message, {VoidCallback? retry}) => FarmerGlassCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      children: [
        Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class _SectionLoading extends StatelessWidget {
  final String label;
  const _SectionLoading({required this.label});
  @override
  Widget build(BuildContext context) => FarmerGlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        const LinearProgressIndicator(minHeight: 2),
      ],
    ),
  );
}
