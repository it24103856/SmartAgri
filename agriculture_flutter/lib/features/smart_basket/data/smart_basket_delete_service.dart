import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class SmartBasketDeleteService {
  static Future<void> delete(String id) async {
    try {
      await ApiClient.instance.dio.delete<void>('/customer-smart-baskets/$id');
    } on DioException catch (error) {
      final data = error.response?.data;

      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Could not confirm deletion. Refresh history and try again.';

      throw BasketDeleteException(message);
    }
  }
}

class BasketDeleteException implements Exception {
  final String message;

  const BasketDeleteException(this.message);

  @override
  String toString() => message;
}
