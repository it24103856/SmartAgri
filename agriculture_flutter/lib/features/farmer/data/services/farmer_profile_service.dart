import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/services/profile_photo.dart';

class FarmerProfileException implements Exception {
  final String message;
  final int? statusCode;

  const FarmerProfileException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class FarmerProfileService {
  FarmerProfileService._();

  static final instance = FarmerProfileService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<UserModel> _request(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();

      return UserModel.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      var message = 'Could not connect. Please try again.';

      if (status == 401) {
        message = 'Your session expired. Please sign in again.';
      } else if (status == 403) {
        message = 'An active farmer account is required.';
      } else if (status == 413) {
        message = 'Choose a photo smaller than 5 MB.';
      } else if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else if (body is Map && body['errors'] is Map) {
        message = (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      throw FarmerProfileException(message, status);
    }
  }

  Future<UserModel> load() {
    return _request(
      () => _dio.get<dynamic>('/farmer-profile'),
    );
  }

  Future<UserModel> save({
    required String fullName,
    required String phone,
    required String address,
    required String city,
    required String province,
    ProfilePhoto? photo,
  }) {
    final fields = <String, dynamic>{
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'province': province.trim(),
    };

    if (photo != null) {
      fields['photo'] = MultipartFile.fromBytes(
        photo.bytes,
        filename: photo.name,
      );
    }

    return _request(
      () => _dio.put<dynamic>(
        '/farmer-profile',
        data: FormData.fromMap(fields),
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }
}