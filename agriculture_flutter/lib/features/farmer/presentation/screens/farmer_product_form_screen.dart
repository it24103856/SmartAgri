import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../products/data/models/catalog_models.dart';
import '../../data/models/farmer_product_models.dart';
import '../../data/services/farmer_product_service.dart';

class FarmerProductFormScreen extends StatefulWidget {
  final FarmerProduct? product;

  const FarmerProductFormScreen({super.key, this.product});

  @override
  State<FarmerProductFormScreen> createState() =>
      _FarmerProductFormScreenState();
}

class _FarmerProductFormScreenState extends State<FarmerProductFormScreen> {
  static const _units = ['kg', 'g', 'piece', 'pack', 'litre'];

  final _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _weightKg;
  late final TextEditingController _stockQuantity;
  late final TextEditingController _nutritionFacts;
  late final TextEditingController _nutritionBasis;
  late final TextEditingController _nutritionSourceName;
  late final TextEditingController _nutritionSourceUrl;

  int? _categoryId;
  String _unit = _units.first;
  bool _isFood = false;

  List<FarmerProductImage> _newImages = [];

  late Future<List<CatalogCategory>> _categoriesFuture;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(
      text: product == null ? '' : product.price.toString(),
    );
    _weightKg = TextEditingController(
      text: product?.weightKg == null ? '' : product!.weightKg.toString(),
    );
    _stockQuantity = TextEditingController(
      text: product == null ? '' : product.stockQuantity.toString(),
    );
    _nutritionFacts = TextEditingController(
      text: product?.nutritionFacts ?? '',
    );
    _nutritionBasis = TextEditingController(
      text: product?.nutritionBasis ?? '',
    );
    _nutritionSourceName = TextEditingController(
      text: product?.nutritionSourceName ?? '',
    );
    _nutritionSourceUrl = TextEditingController(
      text: product?.nutritionSourceUrl ?? '',
    );

    _categoryId = product?.categoryId;
    _unit = product?.unit ?? _units.first;
    _isFood = product?.isFood ?? false;

    _categoriesFuture = _loadCategories();
  }

  Future<List<CatalogCategory>> _loadCategories() async {
    final response = await ApiClient.instance.dio.get<dynamic>(
      '/catalog/categories',
    );

    return (response.data as List)
        .map(
          (item) =>
              CatalogCategory.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _weightKg.dispose();
    _stockQuantity.dispose();
    _nutritionFacts.dispose();
    _nutritionBasis.dispose();
    _nutritionSourceName.dispose();
    _nutritionSourceUrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final images = await FarmerProductService.pickImages();

      if (!mounted || images.isEmpty) return;

      setState(() => _newImages = images);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  bool _validateNutrition() {
    if (!_isFood) return true;

    final values = [
      _nutritionFacts.text.trim(),
      _nutritionBasis.text.trim(),
      _nutritionSourceName.text.trim(),
      _nutritionSourceUrl.text.trim(),
    ];

    final anyFilled = values.any((v) => v.isNotEmpty);
    final allFilled = values.every((v) => v.isNotEmpty);

    if (anyFilled && !allFilled) {
      setState(() {
        _error =
            'Provide nutrition information, reference quantity, source name '
            'and source URL together, or leave all of them empty.';
      });
      return false;
    }

    if (allFilled && !_nutritionSourceUrl.text.trim().startsWith('https://')) {
      setState(() {
        _error = 'Nutrition source must be a valid HTTPS URL.';
      });
      return false;
    }

    return true;
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (!(_form.currentState?.validate() ?? false)) return;

    if (_categoryId == null) {
      setState(() => _error = 'Select a category.');
      return;
    }

    if (!_isEdit && _newImages.isEmpty) {
      setState(() => _error = 'Add at least one product photo.');
      return;
    }

    if (!_validateNutrition()) return;

    setState(() => _saving = true);

    try {
      final product = widget.product;

      if (product == null) {
        await FarmerProductService.instance.create(
          name: _name.text,
          description: _description.text,
          categoryId: _categoryId!,
          price: double.parse(_price.text.trim()),
          unit: _unit,
          weightKg: _weightKg.text.trim().isEmpty
              ? null
              : double.parse(_weightKg.text.trim()),
          stockQuantity: int.parse(_stockQuantity.text.trim()),
          isFood: _isFood,
          nutritionFacts: _nutritionFacts.text,
          nutritionBasis: _nutritionBasis.text,
          nutritionSourceName: _nutritionSourceName.text,
          nutritionSourceUrl: _nutritionSourceUrl.text,
          images: _newImages,
        );
      } else {
        await FarmerProductService.instance.update(
          id: product.id,
          version: product.version,
          name: _name.text,
          description: _description.text,
          categoryId: _categoryId!,
          price: double.parse(_price.text.trim()),
          unit: _unit,
          weightKg: _weightKg.text.trim().isEmpty
              ? null
              : double.parse(_weightKg.text.trim()),
          stockQuantity: int.parse(_stockQuantity.text.trim()),
          isFood: _isFood,
          nutritionFacts: _nutritionFacts.text,
          nutritionBasis: _nutritionBasis.text,
          nutritionSourceName: _nutritionSourceName.text,
          nutritionSourceUrl: _nutritionSourceUrl.text,
          images: _newImages,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Changes submitted for admin review.'
                : 'Product submitted for admin review.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    return null;
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Price is required.';

    final price = double.tryParse(text);
    if (price == null || price <= 0) return 'Enter a valid price.';

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return 'Price can have up to 2 decimal places.';
    }

    return null;
  }

  String? _validateWeight(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final weight = double.tryParse(text);
    if (weight == null || weight <= 0) return 'Enter a valid weight.';

    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
      return 'Weight can have up to 3 decimal places.';
    }

    return null;
  }

  String? _validateStock(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Stock quantity is required.';

    final stock = int.tryParse(text);
    if (stock == null || stock < 0) return 'Enter a valid stock quantity.';

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Add product'),
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
              if (_isEdit)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Saving changes sends this product back for admin '
                    'review. It will not show in the customer catalog '
                    'until approved again.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              _photoSection(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (v) => _required(v, 'Product name'),
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                enabled: !_saving,
              ),
              const SizedBox(height: 12),
              _categoryDropdown(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      decoration: const InputDecoration(
                        labelText: 'Price (Rs.)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validatePrice,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: _units
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _unit = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _stockQuantity,
                      decoration: const InputDecoration(
                        labelText: 'Stock quantity',
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validateStock,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightKg,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg, optional)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateWeight,
                      enabled: !_saving,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFood,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isFood = value),
                activeThumbColor: AppColors.primary,
                title: const Text('This is a food product'),
                subtitle: const Text('Adds optional nutrition information'),
              ),
              if (_isFood) ..._nutritionFields(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Submit for review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _nutritionFields() {
    return [
      const SizedBox(height: 4),
      TextFormField(
        controller: _nutritionFacts,
        decoration: const InputDecoration(labelText: 'Nutrition facts'),
        maxLines: 3,
        enabled: !_saving,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _nutritionBasis,
        decoration: const InputDecoration(
          labelText: 'Reference quantity (e.g. per 100 g)',
        ),
        enabled: !_saving,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _nutritionSourceName,
        decoration: const InputDecoration(labelText: 'Nutrition source name'),
        enabled: !_saving,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _nutritionSourceUrl,
        decoration: const InputDecoration(
          labelText: 'Nutrition source URL (https://...)',
        ),
        keyboardType: TextInputType.url,
        enabled: !_saving,
      ),
    ];
  }

  Widget _categoryDropdown() {
    return FutureBuilder<List<CatalogCategory>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        if (snapshot.hasError) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load categories.',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _categoriesFuture = _loadCategories()),
                child: const Text('Retry'),
              ),
            ],
          );
        }

        final categories = snapshot.data ?? [];

        return DropdownButtonFormField<int>(
          initialValue: categories.any((c) => c.id == _categoryId)
              ? _categoryId
              : null,
          decoration: const InputDecoration(labelText: 'Category'),
          items: categories
              .map(
                (category) => DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                ),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => setState(() => _categoryId = value),
          validator: (value) => value == null ? 'Select a category.' : null,
        );
      },
    );
  }

  Widget _photoSection() {
    final existing = widget.product?.images ?? [];
    final showingNew = _newImages.isNotEmpty;
    final previews = showingNew ? _newImages.length : existing.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < previews; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: showingNew
                        ? Image.memory(
                            _newImages[i].bytes,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          )
                        : SizedBox(
                            width: 84,
                            height: 84,
                            child: _NetworkThumb(existing[i]),
                          ),
                  ),
                ),
              InkWell(
                onTap: _saving ? null : _pickPhotos,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isEdit && !showingNew)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Adding new photos replaces all of the photos above.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        if (showingNew)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton(
              onPressed: _saving ? null : () => setState(() => _newImages = []),
              child: const Text('Remove new photos'),
            ),
          ),
      ],
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
            const Icon(Icons.eco_outlined, color: AppColors.primary),
      ),
    );
  }
}
