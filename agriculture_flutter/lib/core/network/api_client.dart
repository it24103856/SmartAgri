import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../utils/token_storage.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(_options());

    // Separate client for validation: no interceptor recursion.
    _sessionDio = Dio(_options());

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final publicRequest = options.extra['publicRequest'] == true;

            if (!publicRequest) {
              final storage = TokenStorage.instance;
              final token = await storage.getToken();

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
                options.extra['sessionVersion'] = storage.version;
              }
            }

            handler.next(options);
          } catch (error) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: error,
                type: DioExceptionType.unknown,
              ),
            );
          }
        },
        onError: (error, handler) async {
          final requestVersion =
              error.requestOptions.extra['sessionVersion'] as int?;
          final status = error.response?.statusCode;
          final storage = TokenStorage.instance;

          try {
            if (requestVersion != null && requestVersion == storage.version) {
              if (status == 401) {
                await storage.clearSession(expectedVersion: requestVersion);
              } else if (status == 403) {
                // A permission error alone does not mean "log out".
                // Check whether the account/session is actually invalid.
                try {
                  await validateSession();
                } catch (_) {
                  // Network/server failures retain the session.
                  // An invalid session is cleared inside validateSession.
                }
              }
            }
          } catch (_) {
            // Preserve the original API error if secure storage fails.
          }

          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  late final Dio _sessionDio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>?>? _validation;
  int? _validationVersion;

  static BaseOptions _options() => BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  );

  Future<Map<String, dynamic>?> validateSession() async {
    final storage = TokenStorage.instance;
    final token = await storage.getToken();

    if (token == null || token.isEmpty) return null;

    final version = storage.version;
    final pending = _validation;

    if (pending != null && _validationVersion == version) {
      return pending;
    }

    final operation = _validate(token, version);
    _validation = operation;
    _validationVersion = version;

    try {
      return await operation;
    } finally {
      if (identical(_validation, operation)) {
        _validation = null;
        _validationVersion = null;
      }
    }
  }

  Future<Map<String, dynamic>?> _validate(String token, int version) async {
    final storage = TokenStorage.instance;

    try {
      final response = await _sessionDio.get<dynamic>(
        '/auth/session',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (storage.version != version) return null;

      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      if (storage.version != version) return null;

      final status = error.response?.statusCode;
      final data = error.response?.data;

      final inactiveAccount =
          status == 403 && data is Map && data['code'] == 'ACCOUNT_INACTIVE';

      if (status == 401 || inactiveAccount) {
        await storage.clearSession(expectedVersion: version);
        return null;
      }

      // Includes offline, timeouts, 404, and server errors.
      // None of these prove that the saved login is invalid.
      rethrow;
    }
  }
}
