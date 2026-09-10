class CatalogCategory {
  final int id;
  final String name;
  final int productCount;
  final String? imageUrl;

  const CatalogCategory(this.id, this.name, this.productCount, this.imageUrl);

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      (json['id'] as num).toInt(),
      json['name'] as String,
      (json['productCount'] as num).toInt(),
      json['imageUrl'] as String?,
    );
  }
}

class CatalogProduct {
  final int id;
  final int categoryId;
  final int stockQuantity;

  final String name;
  final String categoryName;
  final String unit;

  final String? description;
  final double price;
  final double? weightKg;

  final List<String> images;

  const CatalogProduct({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.categoryName,
    required this.description,
    required this.price,
    required this.unit,
    required this.weightKg,
    required this.stockQuantity,
    required this.images,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final images = (json['imageUrls'] as List? ?? [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    final legacyImage = json['imageUrl'] as String?;

    if (images.isEmpty &&
        legacyImage != null &&
        legacyImage.trim().isNotEmpty) {
      images.add(legacyImage);
    }

    return CatalogProduct(
      id: (json['id'] as num).toInt(),
      categoryId: (json['categoryId'] as num).toInt(),
      name: json['name'] as String,
      categoryName: json['categoryName'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      images: images,
    );
  }

  String? get thumbnail => images.isEmpty ? null : images.first;

  String get formattedPrice => 'Rs. ${price.toStringAsFixed(2)}';

  bool get inStock => stockQuantity > 0;
}

class CatalogPage {
  final List<CatalogProduct> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const CatalogPage(this.items, this.totalCount, this.page, this.pageSize);

  factory CatalogPage.fromJson(Map<String, dynamic> json) {
    return CatalogPage(
      (json['items'] as List)
          .map(
            (item) =>
                CatalogProduct.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      (json['totalCount'] as num).toInt(),
      (json['page'] as num).toInt(),
      (json['pageSize'] as num).toInt(),
    );
  }

  int get totalPages {
    return totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
  }
}

class CatalogData {
  final List<CatalogCategory> categories;
  final CatalogPage products;

  const CatalogData(this.categories, this.products);
}
