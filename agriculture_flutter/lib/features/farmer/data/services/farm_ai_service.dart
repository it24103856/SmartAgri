import 'dart:math';

import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

class FarmAiException implements Exception {
  final String message;

  const FarmAiException(this.message);

  @override
  String toString() => message;
}

class FarmAiService {
  FarmAiService._();

  static final instance = FarmAiService._();

  Dio get _dio => ApiClient.instance.dio;

  // UUID v4. No additional package required.
  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<T> _send<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      if (status == 401) {
        throw const FarmAiException(
          'Your session expired. Please sign in again.',
        );
      }

      if (status == 403) {
        throw const FarmAiException('An active farmer account is required.');
      }

      if (status == 404) {
        throw const FarmAiException('The farm or analysis was not found.');
      }

      if (status == 409) {
        throw const FarmAiException(
          'This request ID was used with different inputs.',
        );
      }

      if (status == null) {
        throw const FarmAiException(
          'Could not receive a response. The analysis may still be '
          'running. Retry the same request or check History.',
        );
      }

      if (body is Map) {
        final errors = body['errors'];

        if (errors is Map) {
          throw FarmAiException(
            errors.values
                .expand((value) => value is List ? value : [value])
                .join('\n'),
          );
        }

        final message = body['message'] ?? body['detail'];

        if (message is String && message.isNotEmpty) {
          throw FarmAiException(message);
        }
      }

      throw FarmAiException('Request failed (HTTP $status).');
    }
  }

  Future<Map<String, dynamic>> analyze(Map<String, dynamic> request) {
    return _send(() async {
      final response = await _dio.post<dynamic>(
        '/AI/analyze-farm',
        data: request,
        options: Options(
          // Override only this request's normal 15-second timeout.
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      return Map<String, dynamic>.from(response.data as Map);
    });
  }

  Future<List<Map<String, dynamic>>> history(int page) {
    return _send(() async {
      final response = await _dio.get<dynamic>(
        '/AI/analyses',
        queryParameters: {'page': page},
      );

      return (response.data as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    });
  }

  Future<Map<String, dynamic>> get(String id) {
    return _send(() async {
      final response = await _dio.get<dynamic>('/AI/analyses/$id');
      return Map<String, dynamic>.from(response.data as Map);
    });
  }
}
