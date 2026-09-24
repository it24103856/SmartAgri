import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_client.dart';
import '../models/farm_model.dart';

class FarmException implements Exception {
  final String message;
  final int? statusCode;

  const FarmException(this.message, [this.statusCode]);

  bool get needsLogin => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class FarmImage {
  final Uint8List bytes;
  final String name;

  const FarmImage(this.bytes, this.name);
}

class FarmService {
  FarmService._();

  static final instance = FarmService._();

  Dio get _dio => ApiClient.instance.dio;

  static const _maxImages = 4;
  static const _maxImageBytes = 5 * 1024 * 1024;

  /// Lets the farmer pick up to [remainingAllowed] photos from gallery.
  static Future<List<FarmImage>> pickImages({
    int remainingAllowed = _maxImages,
  }) async {
    if (remainingAllowed <= 0) return [];

    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
        limit: remainingAllowed,
      );

      final result = <FarmImage>[];

      for (final file in files.take(remainingAllowed)) {
        final bytes = await file.readAsBytes();

        if (bytes.length > _maxImageBytes) {
          throw const FarmException('Choose photos smaller than 5 MB each.');
        }

        result.add(FarmImage(bytes, file.name));
      }

      return result;
    } on PlatformException {
      throw const FarmException(
        'Could not open photos. Please check photo access in device Settings.',
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

  FarmException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final body = error.response?.data;

    if (status == null) {
      return const FarmException(
        'Cannot reach SmartAgri server. Check your connection and try again.',
      );
    }

    if (status == 401) {
      return const FarmException(
        'Your session has expired. Please sign in again.',
        401,
      );
    }

    if (status == 403) {
      return const FarmException('An active farmer account is required.', 403);
    }

    if (status == 404) {
      return const FarmException('This farm was not found.', 404);
    }

    String? message;
    if (body is Map) {
      if (body['message'] is String) {
        message = body['message'] as String;
      } else if (body['errors'] is Map) {
        final errors = body['errors'] as Map;
        message = errors.values.expand((v) => v is List ? v : [v]).join('\n');
      }
    }

    return FarmException(
      message ?? 'An error occurred while processing farm data.',
      status,
    );
  }

  Future<List<FarmModel>> list() {
    return _send(
      () => _dio.get<dynamic>('/farms'),
      (data) => (data as List)
          .map(
            (item) =>
                FarmModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  Future<FarmModel> get(int id) {
    return _send(
      () => _dio.get<dynamic>('/farms/$id'),
      (data) => FarmModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<FarmModel> create({
    required String name,
    String? location,
    required double totalArea,
    required String areaUnit,
    String? soilType,
    String? irrigationType,
    String? mainCrops,
    String? description,
    List<FarmImage> images = const [],
  }) {
    final map = <String, dynamic>{
      'Name': name.trim(),
      'TotalArea': totalArea,
      'AreaUnit': areaUnit,
    };

    if (location != null && location.trim().isNotEmpty) {
      map['Location'] = location.trim();
    }
    if (soilType != null && soilType.trim().isNotEmpty) {
      map['SoilType'] = soilType.trim();
    }
    if (irrigationType != null && irrigationType.trim().isNotEmpty) {
      map['IrrigationType'] = irrigationType.trim();
    }
    if (mainCrops != null && mainCrops.trim().isNotEmpty) {
      map['MainCrops'] = mainCrops.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      map['Description'] = description.trim();
    }

    if (images.isNotEmpty) {
      map['Images'] = [
        for (final img in images)
          MultipartFile.fromBytes(img.bytes, filename: img.name),
      ];
    }

    return _send(
      () => _dio.post<dynamic>('/farms', data: FormData.fromMap(map)),
      (data) => FarmModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<FarmModel> update({
    required int id,
    required String name,
    String? location,
    required double totalArea,
    required String areaUnit,
    String? soilType,
    String? irrigationType,
    String? mainCrops,
    String? description,
    List<String> existingImageUrls = const [],
    List<FarmImage> newImages = const [],
  }) {
    final map = <String, dynamic>{
      'Name': name.trim(),
      'TotalArea': totalArea,
      'AreaUnit': areaUnit,
    };

    if (location != null && location.trim().isNotEmpty) {
      map['Location'] = location.trim();
    }
    if (soilType != null && soilType.trim().isNotEmpty) {
      map['SoilType'] = soilType.trim();
    }
    if (irrigationType != null && irrigationType.trim().isNotEmpty) {
      map['IrrigationType'] = irrigationType.trim();
    }
    if (mainCrops != null && mainCrops.trim().isNotEmpty) {
      map['MainCrops'] = mainCrops.trim();
    }
    if (description != null && description.trim().isNotEmpty) {
      map['Description'] = description.trim();
    }

    if (existingImageUrls.isNotEmpty) {
      map['ExistingImageUrls'] = existingImageUrls;
    }

    if (newImages.isNotEmpty) {
      map['Images'] = [
        for (final img in newImages)
          MultipartFile.fromBytes(img.bytes, filename: img.name),
      ];
    }

    return _send(
      () => _dio.put<dynamic>('/farms/$id', data: FormData.fromMap(map)),
      (data) => FarmModel.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> delete(int id) {
    return _send(() => _dio.delete<dynamic>('/farms/$id'), (_) {});
  }
}
