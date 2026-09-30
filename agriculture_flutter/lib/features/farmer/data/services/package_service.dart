import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../models/package_models.dart';

class PackageException implements Exception {
  final String message;
  final int? statusCode;

  const PackageException(this.message, [this.statusCode]);

  bool get needsLogin => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class PackageService {
  PackageService._();

  static final instance = PackageService._();

  final _bookingChanges = ValueNotifier<int>(0);
  Listenable get bookingChanges => _bookingChanges;

  Dio get _dio => ApiClient.instance.dio;

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

  PackageException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;

    if (status == null) {
      return const PackageException(
        'Cannot reach SmartAgri. Check your connection and try again.',
      );
    }

    String? message;
    if (body is Map && body['message'] is String) {
      message = body['message'] as String;
    }

    return PackageException(
      message ?? 'Something went wrong. Please try again.',
      status,
    );
  }

  Future<List<Package>> list({String? category}) {
    return _send(
      () => _dio.get<dynamic>(
        '/farmer-packages',
        queryParameters: category == null ? null : {'category': category},
      ),
      (data) => (data as List)
          .map(
            (item) => Package.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  Future<PackageQuote> quote({
    required int packageId,
    double? landSizeAcres,
    double? distanceKm,
    double? loadWeightKg,
  }) {
    return _send(
      () => _dio.post<dynamic>(
        '/farmer-packages/quote',
        data: {
          'packageId': packageId,
          'landSizeAcres': ?landSizeAcres,
          'distanceKm': ?distanceKm,
          'loadWeightKg': ?loadWeightKg,
        },
      ),
      (data) => PackageQuote.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<PackageBooking> book({
    required int packageId,
    required int farmId,
    required String serviceDate,
    double? landSizeAcres,
    double? distanceKm,
    double? loadWeightKg,
    String? notes,
  }) async {
    final booking = await _send(
      () => _dio.post<dynamic>(
        '/farmer-packages/bookings',
        data: {
          'packageId': packageId,
          'farmId': farmId,
          'serviceDate': serviceDate,
          'landSizeAcres': ?landSizeAcres,
          'distanceKm': ?distanceKm,
          'loadWeightKg': ?loadWeightKg,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      ),
      (data) => PackageBooking.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    _bookingChanges.value++;
    return booking;
  }

  Future<PackageBooking> cancel(PackageBooking booking) {
    return _send(
      () => _dio.post<dynamic>(
        '/farmer-packages/bookings/${booking.id}/cancel',
        data: {'version': booking.version},
      ),
      (data) => PackageBooking.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<List<PackageBooking>> myBookings() {
    return _send(
      () => _dio.get<dynamic>('/farmer-packages/bookings'),
      (data) => (data as List)
          .map(
            (item) =>
                PackageBooking.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
