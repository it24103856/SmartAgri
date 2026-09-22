import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class SmartBasketException implements Exception {
  final String message;
  final int? statusCode;

  const SmartBasketException(this.message, [this.statusCode]);

  bool get uncertain =>
      statusCode == null || statusCode == 408 || statusCode! >= 500;

  @override
  String toString() => message;
}

class SmartBasketService {
  SmartBasketService._();

  static final instance = SmartBasketService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<dynamic> _send(Future<Response<dynamic>> Function() action) async {
    try {
      return (await action()).data;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      String message = 'Could not confirm the request. Please retry.';

      if (status == 401) {
        message = 'Your session expired. Please sign in again.';
      } else if (status == 403) {
        message = 'An active customer account is required.';
      } else if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else if (body is Map && body['errors'] is Map) {
        message = (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      throw SmartBasketException(message, status);
    }
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final data = await _send(() => _dio.get<dynamic>('/catalog/categories'));

    return (data as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
  }

  Future<Map<String, dynamic>> list({int page = 1}) async {
    final data = await _send(
      () => _dio.get<dynamic>(
        '/customer-smart-baskets',
        queryParameters: {'page': page, 'pageSize': 20},
      ),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> get(String id) async {
    final data = await _send(
      () => _dio.get<dynamic>('/customer-smart-baskets/$id'),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final data = await _send(
      () => _dio.post<dynamic>('/customer-smart-baskets', data: body),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> addableProducts(String id) async {
    final data = await _send(
      () => _dio.get<dynamic>('/customer-smart-baskets/$id/addable-products'),
    );

    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> review(
    String id,
    Map<String, dynamic> body,
  ) async {
    final data = await _send(
      () => _dio.put<dynamic>('/customer-smart-baskets/$id/review', data: body),
    );

    return Map<String, dynamic>.from(data as Map);
  }
}
