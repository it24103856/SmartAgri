import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/catalog_models.dart';

class CatalogException implements Exception {
  final String message;
  final int? status;

  const CatalogException(this.message, [this.status]);

  bool get needsLogin => status == 401 || status == 403;

  @override
  String toString() => message;
}

class CatalogService {
  CatalogService._();

  static final instance = CatalogService._();

  final Dio _dio = ApiClient.instance.dio;

  Future<T> _get<T>(
    String path,
    T Function(dynamic) decode, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);

      return decode(response.data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      final message = switch (status) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'Sign in with an active customer account to browse products.',
        404 => 'This product or page is no longer available.',
        null => 'Cannot reach SmartAgri. Check your connection and try again.',
        _ => 'We could not load the catalog. Please try again.',
      };

      throw CatalogException(message, status);
    } on FormatException {
      throw const CatalogException(
        'We could not read the catalog. Please try again.',
      );
    } on TypeError {
      throw const CatalogException(
        'We could not read the catalog. Please try again.',
      );
    }
  }

  Future<CatalogData> load({
    String search = '',
    int? categoryId,
    String sort = 'latest',
    int page = 1,
    int pageSize = 12,
  }) async {
    final results = await Future.wait<Object>([
      _get<List<CatalogCategory>>(
        '/catalog/categories',
        (data) => (data as List)
            .map(
              (item) => CatalogCategory.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      ),
      _get<CatalogPage>(
        '/catalog/products',
        (data) => CatalogPage.fromJson(Map<String, dynamic>.from(data as Map)),
        {
          if (search.trim().isNotEmpty) 'search': search.trim(),
          'categoryId': ?categoryId,
          'sort': sort,
          'page': page,
          'pageSize': pageSize,
        },
      ),
    ]);

    return CatalogData(
      results[0] as List<CatalogCategory>,
      results[1] as CatalogPage,
    );
  }

  Future<CatalogProduct> product(int id) {
    return _get<CatalogProduct>(
      '/catalog/products/$id',
      (data) => CatalogProduct.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
}
