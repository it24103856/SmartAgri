import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/farm_service.dart';
import '../../data/services/farmer_product_service.dart';
import '../../data/services/package_service.dart';
import '../../data/models/package_models.dart';
import '../widgets/farmer_ui.dart';
import 'farmer_marketplace_screen.dart';
import 'farm_form_screen.dart';
import 'farmer_product_form_screen.dart';

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
  late Future<int> _farms;
  late Future<int> _products;
  late Future<List<PackageBooking>> _bookings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _farms = FarmService.instance.list().then((value) => value.length);
    _products = FarmerProductService.instance
        .list(pageSize: 1)
        .then((value) => value.totalCount);
    _bookings = PackageService.instance.myBookings();
    _farms.ignore();
    _products.ignore();
    _bookings.ignore();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([
      _farms.then<void>((_) {}, onError: (Object _) {}),
      _products.then<void>((_) {}, onError: (Object _) {}),
      _bookings.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  Future<void> _openForm(Widget page) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (saved == true && mounted) await _refresh();
  }

  Widget _metric(Future<int> future, String label, IconData icon) =>
      FutureBuilder<int>(
        future: future,
        builder: (context, snapshot) => FarmerMetric(
          value: snapshot.hasError
              ? 'Unavailable'
              : snapshot.hasData
              ? '${snapshot.data}'
              : '...',
          label: label,
          icon: icon,
        ),
      );

  @override
  Widget build(BuildContext context) => FarmerPage(
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SmartAgri'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Refresh overview',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Your profile',
            onPressed: () => widget.onOpenTab(4),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            FarmerHero(
              eyebrow: 'Your farming companion',
              title:
                  'Welcome, ${widget.fullName.trim().isEmpty ? 'Farmer' : widget.fullName.trim().split(' ').first}.',
              subtitle: 'A little care today. A better harvest tomorrow.',
              icon: Icons.wb_sunny_outlined,
              footer: const Text(
                'YOUR FARM. YOUR GROWTH.',
                style: TextStyle(
                  color: Color(0xFFD7EAB6),
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const FarmerSection(
              'Your farm at a glance',
              subtitle: 'Pull down to refresh your latest numbers.',
            ),
            FarmerMetrics(
              children: [
                _metric(_farms, 'Registered farms', Icons.landscape_outlined),
                _metric(
                  _products,
                  'Product listings',
                  Icons.inventory_2_outlined,
                ),
                FutureBuilder<List<PackageBooking>>(
                  future: _bookings,
                  builder: (context, snapshot) => FarmerMetric(
                    value: snapshot.hasError
                        ? 'Unavailable'
                        : snapshot.hasData
                        ? '${snapshot.data!.where((b) => b.status == 'PENDING' || b.status == 'CONFIRMED').length}'
                        : '...',
                    label: 'Active bookings',
                    icon: Icons.event_available_outlined,
                  ),
                ),
              ],
            ),
            const FarmerSection('What would you like to do?'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _openForm(const FarmFormScreen()),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add farm'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openForm(const FarmerProductFormScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpenTab(2),
                  icon: const Icon(Icons.agriculture_outlined),
                  label: const Text('Book a service'),
                ),
              ],
            ),
            const FarmerSection('Explore your workspace'),
            _WorkspaceCard(
              icon: Icons.landscape_outlined,
              title: 'My farms',
              subtitle: 'Land, crops and growing conditions',
              onTap: () => widget.onOpenTab(1),
            ),
            _WorkspaceCard(
              icon: Icons.inventory_2_outlined,
              title: 'My products',
              subtitle: 'Your harvest, ready for the marketplace',
              onTap: () => widget.onOpenTab(3),
            ),
            _WorkspaceCard(
              icon: Icons.storefront_outlined,
              title: 'Explore the marketplace',
              subtitle: 'Discover produce from the community',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FarmerMarketplaceScreen(),
                ),
              ),
            ),
            const FarmerSection(
              'Recent bookings',
              subtitle: 'Keep track of your service requests.',
            ),
            FutureBuilder<List<PackageBooking>>(
              future: _bookings,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return FarmerEmpty(
                    icon: Icons.cloud_off_outlined,
                    title: 'Bookings unavailable',
                    message: 'Refresh to try again.',
                    onAction: _refresh,
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final recent = [...snapshot.data!]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                if (recent.isEmpty) {
                  return FarmerEmpty(
                    icon: Icons.agriculture_outlined,
                    title: 'A helping hand for your farm',
                    message:
                        'Find machinery, seeds, fertilizer and transport services.',
                    actionLabel: 'Explore packages',
                    onAction: () => widget.onOpenTab(2),
                  );
                }
                return Column(
                  children: recent
                      .take(3)
                      .map(
                        (b) => _WorkspaceCard(
                          icon: Icons.receipt_long_outlined,
                          title: b.packageName,
                          subtitle:
                              '${b.status.toLowerCase()} | Rs. ${b.totalPrice.toStringAsFixed(2)}',
                          onTap: () => widget.onOpenTab(2),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkspaceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.border),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        backgroundColor: AppColors.soft,
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
      onTap: onTap,
    ),
  );
}
