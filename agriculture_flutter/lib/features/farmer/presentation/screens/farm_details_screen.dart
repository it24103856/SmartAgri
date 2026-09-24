import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/farm_model.dart';
import '../../data/services/farm_service.dart';
import 'farm_form_screen.dart';

class FarmDetailsScreen extends StatefulWidget {
  final FarmModel farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  late FarmModel _farm;
  int _activeImageIndex = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
  }

  Future<void> _editFarm() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => FarmFormScreen(farm: _farm)),
    );

    if (updated == true && mounted) {
      try {
        final fresh = await FarmService.instance.get(_farm.id);
        if (mounted) {
          setState(() {
            _farm = fresh;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteFarm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Farm'),
        content: Text(
          'Are you sure you want to delete "${_farm.name}"? This action cannot be undone.',
        ),
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

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await FarmService.instance.delete(_farm.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_farm.name),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Farm',
            onPressed: _deleting ? null : _editFarm,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete Farm',
            onPressed: _deleting ? null : _deleteFarm,
          ),
        ],
      ),
      body: _deleting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageCarousel(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _farm.name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _farm.isActive
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _farm.status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _farm.isActive
                                      ? AppColors.primary
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_farm.location != null &&
                            _farm.location!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _farm.location!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Farm Specifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _specsGrid(),
                        if (_farm.mainCrops != null &&
                            _farm.mainCrops!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Main Crops',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _farm.mainCrops!
                                .split(RegExp(r'[,،]+'))
                                .map((crop) => crop.trim())
                                .where((crop) => crop.isNotEmpty)
                                .map(
                                  (crop) => Chip(
                                    avatar: const Icon(
                                      Icons.eco,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(crop),
                                    backgroundColor: AppColors.soft,
                                    side: BorderSide.none,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (_farm.description != null &&
                            _farm.description!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'About this Farm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              _farm.description!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _imageCarousel() {
    if (_farm.images.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        color: AppColors.soft,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.landscape_outlined, size: 64, color: AppColors.primary),
            SizedBox(height: 8),
            Text(
              'No photos uploaded',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            itemCount: _farm.images.length,
            onPageChanged: (i) => setState(() => _activeImageIndex = i),
            itemBuilder: (context, index) {
              final path = _farm.images[index];
              final uri = Uri.tryParse(path);
              final absolute = uri != null && uri.hasScheme
                  ? path
                  : Uri.parse(ApiClient.instance.dio.options.baseUrl)
                        .resolve('/${path.replaceFirst(RegExp(r'^/+'), '')}')
                        .toString();

              return Image.network(
                absolute,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, error, stackTrace) => Container(
                  color: AppColors.soft,
                  child: const Center(
                    child: Icon(
                      Icons.landscape,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_farm.images.length > 1)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _farm.images.length,
                (index) => Container(
                  width: index == _activeImageIndex ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _activeImageIndex
                        ? AppColors.primary
                        : Colors.white70,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _specsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: [
        _specCard(
          icon: Icons.square_foot,
          title: 'Total Area',
          value: _farm.formattedArea,
        ),
        _specCard(
          icon: Icons.grass,
          title: 'Soil Type',
          value: _farm.soilType ?? 'Not specified',
        ),
        _specCard(
          icon: Icons.water_drop,
          title: 'Irrigation',
          value: _farm.irrigationType ?? 'Not specified',
        ),
        _specCard(
          icon: Icons.calendar_today_outlined,
          title: 'Registered On',
          value:
              '${_farm.createdAt.year}-${_farm.createdAt.month.toString().padLeft(2, '0')}-${_farm.createdAt.day.toString().padLeft(2, '0')}',
        ),
      ],
    );
  }

  Widget _specCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
