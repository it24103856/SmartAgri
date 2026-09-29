import 'package:flutter/material.dart';
import '../widgets/farmer_ui.dart';
import '../widgets/farmer_glass.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/farm_model.dart';
import '../../data/services/farm_service.dart';
import 'farm_details_screen.dart';
import 'farm_form_screen.dart';

class MyFarmsScreen extends StatefulWidget {
  const MyFarmsScreen({super.key});

  @override
  State<MyFarmsScreen> createState() => _MyFarmsScreenState();
}

class _MyFarmsScreenState extends State<MyFarmsScreen> {
  late Future<List<FarmModel>> _future;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  void _loadFarms() {
    if (!mounted) return;
    setState(() {
      _future = FarmService.instance.list();
    });
  }

  Future<void> _refresh() async {
    _loadFarms();
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _openForm({FarmModel? farm}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => FarmFormScreen(farm: farm)),
    );

    if (result == true) {
      _loadFarms();
    }
  }

  Future<void> _openDetails(FarmModel farm) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => FarmDetailsScreen(farm: farm)),
    );
    if (mounted) _loadFarms();
  }

  Future<void> _confirmDelete(FarmModel farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Farm'),
        content: Text('Are you sure you want to delete "${farm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await FarmService.instance.delete(farm.id);
        _loadFarms();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${farm.name}" deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'My Farms',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadFarms,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Farm'),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: FutureBuilder<List<FarmModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final error = snapshot.error;
                final isNeedsLogin = error is FarmException && error.needsLogin;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 80,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 54,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error is FarmException
                                ? error.message
                                : 'Could not load your farms. Please check your connection.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _loadFarms,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: Text(
                              isNeedsLogin ? 'Sign in again' : 'Try Again',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final farms = snapshot.data ?? [];

              if (farms.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 100,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.soft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.landscape_outlined,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No Farms Registered Yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your farmland details, soil specifications, and crops to start managing them.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () => _openForm(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Your First Farm'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: farms.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final areas = <String, double>{};
                    for (final farm in farms) {
                      areas.update(
                        farm.areaUnit,
                        (value) => value + farm.totalArea,
                        ifAbsent: () => farm.totalArea,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FarmerGlassHero(
                          eyebrow: 'Land & growing',
                          title: 'Good things start here.',
                          subtitle:
                              'Your land, growing conditions and crops. All in one place.',
                          icon: Icons.landscape_outlined,
                        ),
                        const SizedBox(height: 16),
                        FarmerMetrics(
                          children: [
                            FarmerGlassMetric(
                              value: '${farms.length}',
                              label: 'Registered farms',
                              icon: Icons.landscape_outlined,
                            ),
                            for (final area in areas.entries)
                              FarmerGlassMetric(
                                value: area.value.toStringAsFixed(1),
                                label: 'Total ${area.key.toLowerCase()}',
                                icon: Icons.square_foot,
                              ),
                          ],
                        ),
                        const FarmerSection(
                          'Your farms',
                          subtitle: 'Choose a farm to explore its details.',
                        ),
                      ],
                    );
                  }
                  final farm = farms[index - 1];
                  return _FarmCard(
                    farm: farm,
                    onTap: () => _openDetails(farm),
                    onEdit: () => _openForm(farm: farm),
                    onDelete: () => _confirmDelete(farm),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final FarmModel farm;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FarmCard({
    required this.farm,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return FarmerGlassCard(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top image banner or header
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _buildImageBanner(),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farm.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (farm.location != null &&
                                farm.location!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      farm.location!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.textSecondary,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') onEdit();
                          if (value == 'delete') onDelete();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Growing conditions
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _badge(
                        icon: Icons.square_foot,
                        label: farm.formattedArea,
                        color: AppColors.primary,
                      ),
                      if (farm.soilType != null && farm.soilType!.isNotEmpty)
                        _badge(
                          icon: Icons.grass,
                          label: farm.soilType!,
                          color: Colors.brown[700]!,
                        ),
                      if (farm.irrigationType != null &&
                          farm.irrigationType!.isNotEmpty)
                        _badge(
                          icon: Icons.water_drop,
                          label: farm.irrigationType!,
                          color: Colors.blue[700]!,
                        ),
                    ],
                  ),
                  if (farm.mainCrops != null && farm.mainCrops!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final crop
                            in farm.mainCrops!
                                .split(',')
                                .map((c) => c.trim())
                                .where((c) => c.isNotEmpty))
                          _badge(
                            icon: Icons.eco_outlined,
                            label: crop,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('View farm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageBanner() {
    if (farm.thumbnail == null) {
      return const FarmerLandscape();
    }

    final path = farm.thumbnail!;
    final uri = Uri.tryParse(path);
    final absolute = uri != null && uri.hasScheme
        ? path
        : Uri.parse(
            ApiClient.instance.dio.options.baseUrl,
          ).resolve('/${path.replaceFirst(RegExp(r'^/+'), '')}').toString();

    return Stack(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Image.network(
            absolute,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => const FarmerLandscape(),
          ),
        ),
        if (farm.images.length > 1)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${farm.images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
