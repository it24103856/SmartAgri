import 'package:flutter/material.dart';
import '../widgets/farmer_glass.dart';

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
            _activeImageIndex = 0;
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
    final crops = (_farm.mainCrops ?? '')
        .split(RegExp(r'[,\u060C]+'))
        .map((crop) => crop.trim())
        .where((crop) => crop.isNotEmpty)
        .toList();

    return FarmerGlassPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Farm overview', style: TextStyle(fontSize: 16)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton.filledTonal(
              tooltip: 'Back',
              style: _toolbarStyle,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 21),
            ),
          ),
          actions: [
            IconButton.filledTonal(
              style: _toolbarStyle,
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Farm',
              onPressed: _deleting ? null : _editFarm,
            ),
            IconButton.filledTonal(
              style: _toolbarStyle,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              tooltip: 'Delete Farm',
              onPressed: _deleting ? null : _deleteFarm,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: _deleting
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _farmHero(),
                      const SizedBox(height: 28),
                      _sectionHeading(
                        'Land, soil & water',
                        'The essentials of your farm',
                      ),
                      const SizedBox(height: 16),
                      _specsGrid(),
                      if (crops.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _sectionHeading('Main crops', 'What grows here'),
                        const SizedBox(height: 14),
                        FarmerGlassCard(
                          padding: const EdgeInsets.all(18),
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final crop in crops)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF0DE),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.eco_rounded,
                                          size: 19,
                                          color: Color(0xFF567245),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            crop,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_farm.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 28),
                        _sectionHeading(
                          'About this farm',
                          'Every plot has a story',
                        ),
                        const SizedBox(height: 14),
                        FarmerGlassCard(
                          padding: const EdgeInsets.all(22),
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              _farm.description!,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.7,
                                color: Color(0xFF656A59),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _editFarm,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF294F3D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          label: const Text('Manage farm details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  ButtonStyle get _toolbarStyle => IconButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: 0.65),
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: Colors.white),
  );

  Widget _sectionHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF7D7D6C)),
      ),
    ],
  );

  Widget _farmHero() => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: _imageCarousel(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 236, 12, 0),
        child: FarmerGlassCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'YOUR LAND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: Color(0xFF867444),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _farm.isActive
                          ? const Color(0xFFE4EEDB)
                          : const Color(0xFFEDE9E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '\u2022  ${_farm.status}',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: _farm.isActive
                            ? const Color(0xFF4E713F)
                            : const Color(0xFF756D5B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _farm.name,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.15,
                  letterSpacing: -0.9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_farm.location?.trim().isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Color(0xFF7C836D),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _farm.location!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF747B65),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  Widget _imageCarousel() {
    if (_farm.images.isEmpty) {
      return SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/plants_bg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              excludeFromSemantics: true,
            ),
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Illustration \u00B7 No photos uploaded',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 280,
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
                  color: const Color(0xFFFFEBC3),
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
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_activeImageIndex + 1} / ${_farm.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_farm.images.length > 1 && _farm.images.length <= 8)
          Positioned(
            bottom: 54,
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

  Widget _specsGrid() => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
      final columns = constraints.maxWidth >= 320 && !largeText ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final specs = [
        (
          Icons.square_foot_rounded,
          'Total Area',
          _farm.formattedArea,
          const Color(0xFFF8E3B6),
          const Color(0xFF907034),
        ),
        (
          Icons.grass_rounded,
          'Soil Type',
          _farm.soilType ?? 'Not specified',
          const Color(0xFFE5ECD7),
          const Color(0xFF657B46),
        ),
        (
          Icons.water_drop_outlined,
          'Irrigation',
          _farm.irrigationType ?? 'Not specified',
          const Color(0xFFE0EDF0),
          const Color(0xFF56818A),
        ),
        (
          Icons.calendar_today_outlined,
          'Registered On',
          '${_farm.createdAt.year}-${_farm.createdAt.month.toString().padLeft(2, '0')}-${_farm.createdAt.day.toString().padLeft(2, '0')}',
          const Color(0xFFF0E5D8),
          const Color(0xFF967854),
        ),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final spec in specs)
            SizedBox(
              width: width,
              child: FarmerGlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: spec.$4,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(spec.$1, size: 22, color: spec.$5),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      spec.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7D7D6C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      spec.$3,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
