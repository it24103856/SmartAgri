import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/token_storage.dart';
import '../models/user_model.dart';
import 'profile_photo.dart';

/// Thrown for any handled auth failure (wrong password, account blocked,
/// email already registered, etc.) so screens can show `.message` directly.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final UserModel user;
  AuthResult({required this.token, required this.user});
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final Dio _dio = ApiClient.instance.dio;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'] as String;
      final userJson = response.data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      await TokenStorage.instance.saveSession(
        token: token,
        role: user.role,
        fullName: user.fullName,
        email: user.email,
      );

      return AuthResult(token: token, user: user);
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(
          e,
          fallback: 'Login failed. Please check your connection.',
        ),
      );
    }
  }

  /// Public registration — backend restricts this to CUSTOMER/FARMER only,
  /// regardless of what role is sent (ADMIN accounts are created by an
  /// existing Admin, not through this screen).
  Future<UserModel> register({
    ProfilePhoto? photo,
    required String fullName,
    required String email,
    required String phone,
    required String address,
    required String city,
    required String province,
    required String password,
    required String role, // 'CUSTOMER' or 'FARMER'
  }) async {
    try {
      final fields = <String, dynamic>{
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'province': province,
        'password': password,
        'role': role,
      };
      final response = await _dio.post(
        photo == null ? ApiConstants.register : '/auth/register-with-photo',
        data: photo == null
            ? fields
            : FormData.fromMap({
                ...fields,
                'photo': MultipartFile.fromBytes(
                  photo.bytes,
                  filename: photo.name,
                ),
              }),
        options: photo == null
            ? null
            : Options(contentType: 'multipart/form-data'),
      );

      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(e, fallback: 'Registration failed. Please try again.'),
      );
    }
  }

  Future<String> updateProfilePhoto(ProfilePhoto photo) async {
    try {
      final response = await _dio.put(
        '/auth/profile-photo',
        data: FormData.fromMap({
          'photo': MultipartFile.fromBytes(photo.bytes, filename: photo.name),
        }),
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data['profileImageUrl'] as String;
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(
          e,
          fallback: 'Could not update your photo. Please try again.',
        ),
      );
    }
  }

  Future<void> logout() async {
    await TokenStorage.instance.clearSession();
  }

  Future<bool> isLoggedIn() => TokenStorage.instance.hasSession();

  String _extractMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return fallback;
  }
}
