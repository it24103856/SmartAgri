class Package {
  final int id;
  final String name;
  final String description;
  final String category; // MACHINERY | INPUTS | TRANSPORT

  final double baseRate;
  final double? minimumCharge;

  final String? cropType;
  final double? quantityPerAcreKg;

  final double? maxLoadKg;
  final double? ratePerExtraKg;

  final bool isActive;
  final String createdByName;
  final List<String> images;

  String? get thumbnail => images.isEmpty ? null : images.first;

  const Package({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.baseRate,
    this.minimumCharge,
    this.cropType,
    this.quantityPerAcreKg,
    this.maxLoadKg,
    this.ratePerExtraKg,
    required this.isActive,
    required this.createdByName,
    this.images = const [],
  });

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      category: (json['category'] as String).toUpperCase(),
      baseRate: (json['baseRate'] as num).toDouble(),
      minimumCharge: (json['minimumCharge'] as num?)?.toDouble(),
      cropType: json['cropType'] as String?,
      quantityPerAcreKg: (json['quantityPerAcreKg'] as num?)?.toDouble(),
      maxLoadKg: (json['maxLoadKg'] as num?)?.toDouble(),
      ratePerExtraKg: (json['ratePerExtraKg'] as num?)?.toDouble(),
      isActive: json['isActive'] == true,
      createdByName: json['createdByName'] as String? ?? 'Admin',
      images: (json['imageUrls'] as List? ?? [])
          .whereType<String>()
          .where((url) => url.trim().isNotEmpty)
          .toList(),
    );
  }

  bool get isMachinery => category == 'MACHINERY';
  bool get isInputs => category == 'INPUTS';
  bool get isTransport => category == 'TRANSPORT';

  static const categoryLabels = {
    'MACHINERY': 'Machinery & Land Prep',
    'INPUTS': 'Seeds & Fertilizer',
    'TRANSPORT': 'Transport & Logistics',
  };

  String get categoryLabel => categoryLabels[category] ?? category;

  String get rateLabel {
    if (isTransport) return 'Rs. ${baseRate.toStringAsFixed(2)} / km';
    if (isMachinery) return 'Rs. ${baseRate.toStringAsFixed(2)} / acre';
    return 'Rs. ${baseRate.toStringAsFixed(2)} / kg';
  }
}

class PackageQuote {
  final int packageId;
  final String category;
  final double calculatedQuantity;
  final String quantityUnit;
  final double totalPrice;

  const PackageQuote({
    required this.packageId,
    required this.category,
    required this.calculatedQuantity,
    required this.quantityUnit,
    required this.totalPrice,
  });

  factory PackageQuote.fromJson(Map<String, dynamic> json) {
    return PackageQuote(
      packageId: (json['packageId'] as num).toInt(),
      category: json['category'] as String,
      calculatedQuantity: (json['calculatedQuantity'] as num).toDouble(),
      quantityUnit: json['quantityUnit'] as String,
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }
}

class PackageBooking {
  final int id;
  final int packageId;
  final String packageName;
  final String category;

  final double? landSizeAcres;
  final double? distanceKm;
  final double? loadWeightKg;

  final double calculatedQuantity;
  final double totalPrice;

  final String status;
  final String? notes;
  final String? adminNote;
  final DateTime createdAt;

  final String version;
  final int? farmId;
  final String? farmName;
  final String? farmLocation;
  final String? serviceDate;
  final bool requiresAdvancePayment;

  const PackageBooking({
    required this.id,
    required this.packageId,
    required this.packageName,
    required this.category,
    this.landSizeAcres,
    this.distanceKm,
    this.loadWeightKg,
    required this.calculatedQuantity,
    required this.totalPrice,
    required this.status,
    this.notes,
    this.adminNote,
    required this.createdAt,
    this.version = '',
    this.farmId,
    this.farmName,
    this.farmLocation,
    this.serviceDate,
    this.requiresAdvancePayment = false,
  });

  factory PackageBooking.fromJson(Map<String, dynamic> json) {
    return PackageBooking(
      id: (json['id'] as num).toInt(),
      packageId: (json['packageId'] as num).toInt(),
      packageName: json['packageName'] as String,
      category: json['category'] as String,
      landSizeAcres: (json['landSizeAcres'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      loadWeightKg: (json['loadWeightKg'] as num?)?.toDouble(),
      calculatedQuantity: (json['calculatedQuantity'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: (json['status'] as String).toUpperCase(),
      notes: json['notes'] as String?,
      adminNote: json['adminNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      version: json['version'] as String? ?? '',
      farmId: (json['farmId'] as num?)?.toInt(),
      farmName: json['farmName'] as String?,
      farmLocation: json['farmLocation'] as String?,
      serviceDate: json['serviceDate'] as String?,
      requiresAdvancePayment: json['requiresAdvancePayment'] == true,
    );
  }
}
