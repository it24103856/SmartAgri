import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../models/farmer_product_models.dart';

class FarmerProductException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>>? fieldErrors;

  const FarmerProductException(
    this.message, [
    this.statusCode,
    this.fieldErrors,
  ]);

  bool get needsLogin => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class FarmerProductImage {
  final Uint8List bytes;
  final String name;

  const FarmerProductImage(this.bytes, this.name);
}

class FarmerProductService {
  FarmerProductService._();

  static final instance = FarmerProductService._();

  Dio get _dio => ApiClient.instance.dio;

  static const _maxImages = 5;
  static const _maxImageBytes = 5 * 1024 * 1024;

  /// Lets the farmer pick up to [_maxImages] photos from the gallery.
  /// Uploading new photos replaces all previous photos on that product.
  static Future<List<FarmerProductImage>> pickImages() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        limit: _maxImages,
      );

      final result = <FarmerProductImage>[];

      for (final file in files.take(_maxImages)) {
        final bytes = await file.readAsBytes();

        if (bytes.length > _maxImageBytes) {
          throw const FarmerProductException(
            'Choose photos smaller than 5 MB each.',
          );
        }

        result.add(FarmerProductImage(bytes, file.name));
      }

      return result;
    } on PlatformException {
      throw const FarmerProductException(
        'Could not open your photos. Check photo access in Settings and try again.',
      );
    }
  }

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() send,
    T Function(dynamic) decode,
  ) async {
    try {
      final response = await send();

      return decode(response.data);
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  FarmerProductException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;

    if (status == null) {
      return const FarmerProductException(
        'Cannot reach SmartAgri. Check your connection and try again.',
      );
    }

    if (status == 401) {
      return const FarmerProductException(
        'Your session has expired. Please sign in again.',
        401,
      );
    }

    if (status == 403) {
      return const FarmerProductException(
        'An active farmer account is required.',
        403,
      );
    }

    if (status == 404) {
      return const FarmerProductException(
        'This product is no longer available.',
        404,
      );
    }

    String? message;
    Map<String, List<String>>? fieldErrors;

    if (body is Map) {
      if (body['message'] is String) {
        message = body['message'] as String;
      }

      if (body['errors'] is Map) {
        fieldErrors = (body['errors'] as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            value is List
                ? value.map((e) => e.toString()).toList()
                : [value.toString()],
          ),
        );

        message ??= fieldErrors.values.expand((v) => v).join('\n');
      }
    }

    return FarmerProductException(
      message ?? 'We could not save this product. Please try again.',
      status,
      fieldErrors,
    );
  }

  Future<FarmerProductPage> list({int page = 1, int pageSize = 20}) {
    return _send(
      () => _dio.get<dynamic>(
        '/farmer-products',
        queryParameters: {'page': page, 'pageSize': pageSize},
      ),
      (data) =>
          FarmerProductPage.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<FarmerProduct> get(int id) {
    return _send(
      () => _dio.get<dynamic>('/farmer-products/$id'),
      (data) => FarmerProduct.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<FarmerProduct> create({
    required String name,
    String? description,
    required int categoryId,
    required double price,
    required String unit,
    double? weightKg,
    required int stockQuantity,
    bool isFood = false,
    String? nutritionFacts,
    String? nutritionBasis,
    String? nutritionSourceName,
    String? nutritionSourceUrl,
    required List<FarmerProductImage> images,
  }) {
    final fields = _fields(
      name: name,
      description: description,
      categoryId: categoryId,
      price: price,
      unit: unit,
      weightKg: weightKg,
      stockQuantity: stockQuantity,
      isFood: isFood,
      nutritionFacts: nutritionFacts,
      nutritionBasis: nutritionBasis,
      nutritionSourceName: nutritionSourceName,
      nutritionSourceUrl: nutritionSourceUrl,
      images: images,
    );

    return _send(
      () => _dio.post<dynamic>(
        '/farmer-products',
        data: FormData.fromMap(fields),
        options: Options(contentType: 'multipart/form-data'),
      ),
      (data) => FarmerProduct.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<FarmerProduct> update({
    required int id,
    required String version,
    required String name,
    String? description,
    required int categoryId,
    required double price,
    required String unit,
    double? weightKg,
    required int stockQuantity,
    bool isFood = false,
    String? nutritionFacts,
    String? nutritionBasis,
    String? nutritionSourceName,
    String? nutritionSourceUrl,
    List<FarmerProductImage> images = const [],
  }) {
    final fields = _fields(
      name: name,
      description: description,
      categoryId: categoryId,
      price: price,
      unit: unit,
      weightKg: weightKg,
      stockQuantity: stockQuantity,
      isFood: isFood,
      nutritionFacts: nutritionFacts,
      nutritionBasis: nutritionBasis,
      nutritionSourceName: nutritionSourceName,
      nutritionSourceUrl: nutritionSourceUrl,
      images: images,
    );

    fields['Version'] = version;

    return _send(
      () => _dio.put<dynamic>(
        '/farmer-products/$id',
        data: FormData.fromMap(fields),
        options: Options(contentType: 'multipart/form-data'),
      ),
      (data) => FarmerProduct.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Map<String, dynamic> _fields({
    required String name,
    String? description,
    required int categoryId,
    required double price,
    required String unit,
    double? weightKg,
    required int stockQuantity,
    required bool isFood,
    String? nutritionFacts,
    String? nutritionBasis,
    String? nutritionSourceName,
    String? nutritionSourceUrl,
    required List<FarmerProductImage> images,
  }) {
    return {
      'Name': name.trim(),
      if (description != null && description.trim().isNotEmpty)
        'Description': description.trim(),
      'CategoryId': categoryId.toString(),
      'Price': price.toString(),
      'Unit': unit,
      if (weightKg != null) 'WeightKg': weightKg.toString(),
      'StockQuantity': stockQuantity.toString(),
      'IsFood': isFood.toString(),
      if (isFood && (nutritionFacts ?? '').trim().isNotEmpty)
        'NutritionFacts': nutritionFacts!.trim(),
      if (isFood && (nutritionBasis ?? '').trim().isNotEmpty)
        'NutritionBasis': nutritionBasis!.trim(),
      if (isFood && (nutritionSourceName ?? '').trim().isNotEmpty)
        'NutritionSourceName': nutritionSourceName!.trim(),
      if (isFood && (nutritionSourceUrl ?? '').trim().isNotEmpty)
        'NutritionSourceUrl': nutritionSourceUrl!.trim(),
      if (images.isNotEmpty)
        'Images': images
            .map(
              (image) =>
                  MultipartFile.fromBytes(image.bytes, filename: image.name),
            )
            .toList(),
    };
  }
}
