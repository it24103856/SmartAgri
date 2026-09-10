import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../products/data/services/catalog_service.dart';

class CartLine {
  final int productId;
  final int quantity;
  final int stockQuantity;

  final String name;
  final String unit;
  final String? imageUrl;

  final double unitPrice;
  final double lineTotal;
  final bool available;

  CartLine.fromJson(Map<String, dynamic> json)
    : productId = (json['productId'] as num).toInt(),
      quantity = (json['quantity'] as num).toInt(),
      stockQuantity = (json['stockQuantity'] as num).toInt(),
      name = json['name'] as String,
      unit = json['unit'] as String,
      imageUrl = json['imageUrl'] as String?,
      unitPrice = (json['unitPrice'] as num).toDouble(),
      lineTotal = (json['lineTotal'] as num).toDouble(),
      available = json['available'] as bool;
}

class CartData {
  final List<CartLine> items;
  final double subtotal;
  final bool canCheckout;

  CartData.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map(
            (item) => CartLine.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      subtotal = (json['subtotal'] as num).toDouble(),
      canCheckout = json['canCheckout'] as bool;
}

class CartService {
  CartService._();

  static final instance = CartService._();

  final productCount = ValueNotifier<int>(0);

  Future<void> refreshProductCount() async {
    try {
      await load();
    } catch (_) {
      // Keep the last known count if the cart cannot be refreshed.
    }
  }

  Dio get _dio => ApiClient.instance.dio;

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      final String message;

      if (status == 401) {
        message = 'Your session has expired. Please sign in again.';
      } else if (status == 403) {
        message = 'An active customer account is required.';
      } else if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else {
        message =
            'Connection problem. Check your cart before '
            'retrying an add.';
      }

      throw CatalogException(message, status);
    }
  }

  Future<CartData> load({bool review = false}) async {
    final response = await _request(
      () => _dio.get<dynamic>(review ? '/cart/checkout-preview' : '/cart'),
    );

    final cart = CartData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
    productCount.value = cart.items
        .map((item) => item.productId)
        .toSet()
        .length;
    return cart;
  }

  Future<CartData> buyNow(int productId, int quantity) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        '/cart/buy-now-preview',
        data: {'productId': productId, 'quantity': quantity},
      ),
    );

    return CartData.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> add(int productId, int quantity) async {
    await _request(
      () => _dio.post<dynamic>(
        '/cart/items',
        data: {'productId': productId, 'quantity': quantity},
      ),
    );
    await refreshProductCount();
  }

  Future<void> setQuantity(int productId, int quantity) async {
    await _request(
      () => _dio.put<dynamic>(
        '/cart/items/$productId',
        data: {'quantity': quantity},
      ),
    );
  }

  Future<void> remove(int productId) async {
    await _request(() => _dio.delete<dynamic>('/cart/items/$productId'));
    await refreshProductCount();
  }
}
