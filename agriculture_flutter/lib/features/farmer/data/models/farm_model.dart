class FarmModel {
  final int id;
  final int farmerId;
  final String name;
  final String? location;
  final double totalArea;
  final String areaUnit;
  final String? soilType;
  final String? irrigationType;
  final String? mainCrops;
  final String? description;
  final List<String> images;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const FarmModel({
    required this.id,
    required this.farmerId,
    required this.name,
    this.location,
    required this.totalArea,
    required this.areaUnit,
    this.soilType,
    this.irrigationType,
    this.mainCrops,
    this.description,
    required this.images,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    final images = (json['imageUrls'] as List? ?? [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();

    return FarmModel(
      id: (json['id'] as num).toInt(),
      farmerId: (json['farmerId'] as num).toInt(),
      name: json['name'] as String,
      location: json['location'] as String?,
      totalArea: (json['totalArea'] as num).toDouble(),
      areaUnit: (json['areaUnit'] as String?) ?? 'Acres',
      soilType: json['soilType'] as String?,
      irrigationType: json['irrigationType'] as String?,
      mainCrops: json['mainCrops'] as String?,
      description: json['description'] as String?,
      images: images,
      status: (json['status'] as String?) ?? 'ACTIVE',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  String? get thumbnail => images.isEmpty ? null : images.first;

  String get formattedArea {
    final areaStr = totalArea % 1 == 0
        ? totalArea.toInt().toString()
        : totalArea.toString();
    return '$areaStr $areaUnit';
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';
}
