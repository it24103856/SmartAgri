class FarmerProduct {
  final int id;

  final String name;
  final String? description;

  final int categoryId;
  final String categoryName;

  final double price;
  final String unit;
  final double? weightKg;
  final int stockQuantity;

  final List<String> images;

  final String status; // PENDING | APPROVED | REJECTED
  final String? rejectionReason;
  final String? reviewedByName;

  final bool isFood;
  final String? nutritionFacts;
  final String? nutritionBasis;
  final String? nutritionSourceName;
  final String? nutritionSourceUrl;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;

  final String version;

  const FarmerProduct({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.categoryName,
    required this.price,
    required this.unit,
    this.weightKg,
    required this.stockQuantity,
    required this.images,
    required this.status,
    this.rejectionReason,
    this.reviewedByName,
    this.isFood = false,
    this.nutritionFacts,
    this.nutritionBasis,
    this.nutritionSourceName,
    this.nutritionSourceUrl,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    required this.version,
  });

  factory FarmerProduct.fromJson(Map<String, dynamic> json) {
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

    return FarmerProduct(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      stockQuantity: (json['stockQuantity'] as num).toInt(),
      images: images,
      status: (json['status'] as String).toUpperCase(),
      rejectionReason: json['rejectionReason'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
      isFood: json['isFood'] == true,
      nutritionFacts: json['nutritionFacts'] as String?,
      nutritionBasis: json['nutritionBasis'] as String?,
      nutritionSourceName: json['nutritionSourceName'] as String?,
      nutritionSourceUrl: json['nutritionSourceUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      version: json['version'] as String,
    );
  }

  String? get thumbnail => images.isEmpty ? null : images.first;

  String get formattedPrice => 'Rs. ${price.toStringAsFixed(2)} / $unit';

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
}

class FarmerProductPage {
  final List<FarmerProduct> items;
  final int totalCount;
  final int page;
  final int pageSize;

  const FarmerProductPage(
    this.items,
    this.totalCount,
    this.page,
    this.pageSize,
  );

  factory FarmerProductPage.fromJson(Map<String, dynamic> json) {
    return FarmerProductPage(
      (json['items'] as List)
          .map(
            (item) =>
                FarmerProduct.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      (json['totalCount'] as num).toInt(),
      (json['page'] as num).toInt(),
      (json['pageSize'] as num).toInt(),
    );
  }

  int get totalPages => totalCount == 0 ? 1 : (totalCount / pageSize).ceil();
}
