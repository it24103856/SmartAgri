import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/farm_model.dart';
import '../../data/services/farm_service.dart';

class FarmFormScreen extends StatefulWidget {
  final FarmModel? farm;

  const FarmFormScreen({super.key, this.farm});

  @override
  State<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends State<FarmFormScreen> {
  static const _areaUnits = ['Acres', 'Perches', 'Hectares'];
  static const _soilTypes = [
    'Loamy (ලෝම)',
    'Clay (මැටි)',
    'Sandy (වැලි)',
    'Silt (මඩ/රොන්මඩ)',
    'Peat (පීට්)',
    'Other (වෙනත්)',
  ];
  static const _irrigationTypes = [
    'Rainfed (වැසි ජලය)',
    'Drip Irrigation (බිංදු ජල සම්පාදනය)',
    'Sprinkler (විදින ජල සම්පාදනය)',
    'Canal / Surface (ඇළ මාර්ග)',
    'Well / Groundwater (ළිං ජලය)',
    'Other (වෙනත්)',
  ];

  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _totalArea;
  late final TextEditingController _mainCrops;
  late final TextEditingController _description;

  String _areaUnit = _areaUnits.first;
  String? _soilType;
  String? _irrigationType;

  List<String> _existingImages = [];
  final List<FarmImage> _newImages = [];

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.farm != null;
  int get _totalPhotos => _existingImages.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    final farm = widget.farm;

    _name = TextEditingController(text: farm?.name ?? '');
    _location = TextEditingController(text: farm?.location ?? '');
    _totalArea = TextEditingController(
      text: farm == null
          ? ''
          : (farm.totalArea % 1 == 0
                ? farm.totalArea.toInt().toString()
                : farm.totalArea.toString()),
    );
    _mainCrops = TextEditingController(text: farm?.mainCrops ?? '');
    _description = TextEditingController(text: farm?.description ?? '');

    _areaUnit = farm?.areaUnit != null && _areaUnits.contains(farm!.areaUnit)
        ? farm.areaUnit
        : _areaUnits.first;

    if (farm?.soilType != null && farm!.soilType!.isNotEmpty) {
      final match = _soilTypes.firstWhere(
        (s) => s.toLowerCase().startsWith(farm.soilType!.toLowerCase()),
        orElse: () => farm.soilType!,
      );
      _soilType = match;
    }

    if (farm?.irrigationType != null && farm!.irrigationType!.isNotEmpty) {
      final match = _irrigationTypes.firstWhere(
        (i) => i.toLowerCase().startsWith(farm.irrigationType!.toLowerCase()),
        orElse: () => farm.irrigationType!,
      );
      _irrigationType = match;
    }

    _existingImages = List.from(farm?.images ?? []);
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _totalArea.dispose();
    _mainCrops.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = 4 - _totalPhotos;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 4 photos per farm.')),
      );
      return;
    }

    try {
      final picked = await FarmService.pickImages(remainingAllowed: remaining);
      if (picked.isNotEmpty && mounted) {
        setState(() {
          _newImages.addAll(picked);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Farm name is required.';
    if (text.length < 2) return 'Farm name must be at least 2 characters.';
    return null;
  }

  String? _validateArea(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Farm area is required.';
    final val = double.tryParse(text);
    if (val == null || val <= 0) return 'Enter a valid area greater than 0.';
    return null;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _name.text.trim();
    final location = _location.text.trim().isEmpty
        ? null
        : _location.text.trim();
    final area = double.parse(_totalArea.text.trim());
    final soil = _soilType?.split(' ').first;
    final irrigation = _irrigationType?.split(' ').first;
    final crops = _mainCrops.text.trim().isEmpty
        ? null
        : _mainCrops.text.trim();
    final desc = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();

    try {
      if (_isEdit) {
        await FarmService.instance.update(
          id: widget.farm!.id,
          name: name,
          location: location,
          totalArea: area,
          areaUnit: _areaUnit,
          soilType: soil,
          irrigationType: irrigation,
          mainCrops: crops,
          description: desc,
          existingImageUrls: _existingImages,
          newImages: _newImages,
        );
      } else {
        await FarmService.instance.create(
          name: name,
          location: location,
          totalArea: area,
          areaUnit: _areaUnit,
          soilType: soil,
          irrigationType: irrigation,
          mainCrops: crops,
          description: desc,
          images: _newImages,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Farm' : 'Add New Farm'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _photoSection(),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Farm Name *',
                  hintText: 'e.g. Green Valley Farm',
                  prefixIcon: Icon(Icons.landscape_outlined),
                ),
                validator: _validateName,
                enabled: !_saving,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location / Address',
                  hintText: 'e.g. Kurunegala, North Western',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _totalArea,
                      decoration: const InputDecoration(
                        labelText: 'Total Area *',
                        hintText: 'e.g. 2.5',
                        prefixIcon: Icon(Icons.square_foot_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateArea,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _areaUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _areaUnits
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _areaUnit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _soilType,
                decoration: const InputDecoration(
                  labelText: 'Soil Type (පස වර්ගය)',
                  prefixIcon: Icon(Icons.grass_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select soil type (Optional)'),
                  ),
                  ..._soilTypes.map(
                    (s) => DropdownMenuItem<String>(value: s, child: Text(s)),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _soilType = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _irrigationType,
                decoration: const InputDecoration(
                  labelText: 'Irrigation Type (ජල සම්පාදනය)',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Select irrigation type (Optional)'),
                  ),
                  ..._irrigationTypes.map(
                    (i) => DropdownMenuItem<String>(value: i, child: Text(i)),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _irrigationType = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mainCrops,
                decoration: const InputDecoration(
                  labelText: 'Main Crops (ප්‍රධාන බෝග)',
                  hintText: 'e.g. Paddy, Coconut, Banana, Vegetables',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description / Notes (Optional)',
                  hintText:
                      'Additional details about soil condition, water source, etc.',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                enabled: !_saving,
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Save Changes' : 'Register Farm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Farm Photos (Max 4, Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            Text(
              '$_totalPhotos / 4',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Existing images
              for (var i = 0; i < _existingImages.length; i++)
                _buildPhotoThumb(
                  child: _NetworkThumb(_existingImages[i]),
                  onRemove: _saving ? null : () => _removeExistingImage(i),
                ),

              // Newly picked images
              for (var i = 0; i < _newImages.length; i++)
                _buildPhotoThumb(
                  child: Image.memory(
                    _newImages[i].bytes,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                  onRemove: _saving ? null : () => _removeNewImage(i),
                ),

              // Add button
              if (_totalPhotos < 4)
                InkWell(
                  onTap: _saving ? null : _pickPhotos,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoThumb({required Widget child, VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 90, height: 90, child: child),
          ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkThumb extends StatelessWidget {
  final String path;

  const _NetworkThumb(this.path);

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(path);
    final absolute = uri != null && uri.hasScheme
        ? path
        : Uri.parse(
            ApiClient.instance.dio.options.baseUrl,
          ).resolve('/${path.replaceFirst(RegExp(r'^/+'), '')}').toString();

    return ColoredBox(
      color: AppColors.soft,
      child: Image.network(
        absolute,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) =>
            const Icon(Icons.landscape_outlined, color: AppColors.primary),
      ),
    );
  }
}
