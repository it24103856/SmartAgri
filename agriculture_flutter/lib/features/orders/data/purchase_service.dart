import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class PurchaseException implements Exception {
  final String message;
  final int? statusCode;

  const PurchaseException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class PurchaseOrder {
  final Map<String, dynamic> json;

  PurchaseOrder.fromJson(Map<String, dynamic> value) : json = value;

  int get id => (json['id'] as num).toInt();

  String get status => json['status'] as String;

  double get subtotal => (json['subtotal'] as num).toDouble();

  double get deliveryFee => (json['deliveryFee'] as num).toDouble();

  double get total => (json['totalAmount'] as num).toDouble();

  String get fullName => json['fullName'] as String;
  String get phone => json['phone'] as String;
  String get address => json['address'] as String;
  String get city => json['city'] as String;

  String? get reviewReason => json['reviewReason'] as String?;

  Map<String, dynamic> get payment =>
      Map<String, dynamic>.from(json['payment'] as Map);

  String get paymentMethod => payment['method'] as String;

  String get paymentStatus => payment['status'] as String;

  String? get paymentReference => payment['providerPaymentId'] as String?;

  List<Map<String, dynamic>> get items => (json['items'] as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();

  bool get pending => paymentMethod == 'PAYHERE' && paymentStatus == 'Pending';

  bool get canCancel =>
      status == 'Confirmed' &&
      paymentMethod == 'COD' &&
      paymentStatus == 'Unpaid';

  bool get isAcceptedOrder => const {
    'Confirmed',
    'Preparing',
    'Packed',
    'Dispatched',
    'Delivered',
  }.contains(status);

  bool get paidAndConfirmed => paymentStatus == 'Paid' && isAcceptedOrder;

  bool get codConfirmed =>
      paymentMethod == 'COD' && paymentStatus == 'Unpaid' && isAcceptedOrder;
}

class PurchaseService {
  PurchaseService._();
  Future<PurchaseTracking> tracking(int orderId) async {
    final result = await _request(
      () => _dio.get<dynamic>('/customer-orders/$orderId/tracking'),
    );

    return PurchaseTracking.fromJson(Map<String, dynamic>.from(result as Map));
  }

  static final instance = PurchaseService._();

  Future<void> cancelOrder(int orderId, String reason) async {
    await _request(
      () => _dio.post<dynamic>(
        '/customer-orders/$orderId/cancel',
        data: {'reason': reason.trim()},
      ),
    );
  }

  Dio get _dio => ApiClient.instance.dio;

  static String newRequestId() {
    final random = Random.secure();

    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // UUID version 4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  Future<dynamic> _request(Future<Response<dynamic>> Function() send) async {
    try {
      return (await send()).data;
    } on DioException catch (error) {
      final body = error.response?.data;
      final status = error.response?.statusCode;

      String message = 'Connection problem. Please try again.';

      if (status == 401) {
        message = 'Your session expired. Please sign in again.';
      } else if (status == 403) {
        message = 'An active customer account is required.';
      } else if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else if (body is Map && body['errors'] is Map) {
        final errors = body['errors'] as Map;

        message = errors.values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      throw PurchaseException(message, status);
    }
  }

  Future<PurchaseOrder> create(Map<String, dynamic> body) async {
    final result = await _request(
      () => _dio.post<dynamic>('/customer-orders', data: body),
    );

    return PurchaseOrder.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<PurchaseOrder> get(int id) async {
    final result = await _request(
      () => _dio.get<dynamic>('/customer-orders/$id'),
    );

    return PurchaseOrder.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<List<PurchaseOrder>> list() async {
    final result = await _request(() => _dio.get<dynamic>('/customer-orders'));

    return (result as List)
        .map(
          (item) =>
              PurchaseOrder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<Uri> paymentUrl(int orderId) async {
    final result = await _request(
      () => _dio.post<dynamic>('/customer-payments/$orderId/session'),
    );

    return Uri.parse((result as Map)['url'] as String);
  }
}

class PurchaseTracking {
  final PurchaseOrder order;
  final List<Map<String, dynamic>> history;

  const PurchaseTracking({required this.order, required this.history});

  factory PurchaseTracking.fromJson(Map<String, dynamic> json) {
    return PurchaseTracking(
      order: PurchaseOrder.fromJson(
        Map<String, dynamic>.from(json['order'] as Map),
      ),
      history: (json['history'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}
