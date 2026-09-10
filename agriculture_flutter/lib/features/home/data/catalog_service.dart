import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

String? catalogImageUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  final base = Uri.parse(ApiConstants.baseUrl);
  final uri = base.resolve(path);
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  // Uploaded image paths resolve against the same host as the API.
  return uri.toString();
}

class CatalogCategory {
  final int id;
  final String name;
  final String? imageUrl;
  CatalogCategory.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      name = json['name'] as String,
      imageUrl = catalogImageUrl(json['imageUrl'] as String?);
}

class CatalogProduct {
  final int id, categoryId, stockQuantity;
  final String name, categoryName, unit;
  final String? description, imageUrl;
  final double price;
  CatalogProduct.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      categoryId = json['categoryId'] as int,
      stockQuantity = json['stockQuantity'] as int,
      name = json['name'] as String,
      categoryName = json['categoryName'] as String,
      unit = json['unit'] as String,
      description = json['description'] as String?,
      price = (json['price'] as num).toDouble(),
      imageUrl = catalogImageUrl(
        (json['imageUrls'] as List?)?.isNotEmpty == true
            ? (json['imageUrls'] as List).first as String
            : json['imageUrl'] as String?,
      ),
      assert((json['price'] as num) >= 0);
}

class CatalogData {
  final String fullName;
  final String? profileImageUrl;
  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  CatalogData.fromJson(Map<String, dynamic> json)
    : fullName = json['fullName'] as String,
      profileImageUrl = catalogImageUrl(json['profileImageUrl'] as String?),
      categories = (json['categories'] as List)
          .map((c) => CatalogCategory.fromJson(c as Map<String, dynamic>))
          .toList(),
      products = (json['products'] as List)
          .map((p) => CatalogProduct.fromJson(p as Map<String, dynamic>))
          .toList();
}

class CatalogException implements Exception {
  final String message;
  final bool sessionExpired;
  const CatalogException(this.message, {this.sessionExpired = false});
}

class CatalogService {
  static Future<CatalogData> load() async {
    try {
      final response = await ApiClient.instance.dio.get('/catalog');
      return CatalogData.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        throw const CatalogException(
          'Your session has expired. Please sign in again.',
          sessionExpired: true,
        );
      }
      if (error.response?.statusCode == 403) {
        throw const CatalogException('An active customer account is required.');
      }
      throw const CatalogException(
        'Could not load the shop. Check your connection and try again.',
      );
    }
  }
}
