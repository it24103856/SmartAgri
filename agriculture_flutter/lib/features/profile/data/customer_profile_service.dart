import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/data/services/profile_photo.dart';

class CustomerProfileException implements Exception {
  final String message;
  final int? statusCode;

  const CustomerProfileException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class CustomerProfileService {
  CustomerProfileService._();

  static final instance = CustomerProfileService._();

  Dio get _dio => ApiClient.instance.dio;

  Future<UserModel> _request(Future<Response<dynamic>> Function() send) async {
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
        message = 'An active customer account is required.';
      } else if (body is Map && body['message'] is String) {
        message = body['message'] as String;
      } else if (body is Map && body['errors'] is Map) {
        message = (body['errors'] as Map).values
            .expand((value) => value is List ? value : [value])
            .join('\n');
      }

      throw CustomerProfileException(message, status);
    }
  }

  Future<UserModel> load() {
    return _request(() => _dio.get<dynamic>('/customer-profile'));
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
        '/customer-profile',
        data: FormData.fromMap(fields),
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }
}
