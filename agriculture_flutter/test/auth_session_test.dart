import 'package:agriculture_flutter/core/network/api_client.dart';
import 'package:agriculture_flutter/core/utils/token_storage.dart';
import 'package:agriculture_flutter/features/auth/data/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  final storage = TokenStorage.instance;
  String role = 'CUSTOMER';
  String status = 'ACTIVE';
  late Interceptor mock;

  setUp(() async {
    await storage.clearSession();
    role = 'CUSTOMER';
    status = 'ACTIVE';
    mock = InterceptorsWrapper(
      onRequest: (options, handler) {
        expect(options.extra['publicRequest'], isTrue);
        handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'token': 'test-session',
              'user': {
                'id': 1,
                'fullName': 'Test Customer',
                'email': 'customer@example.com',
                'role': role,
                'status': status,
                'createdAt': '2026-01-01T00:00:00Z',
              },
            },
          ),
        );
      },
    );
    ApiClient.instance.dio.interceptors.add(mock);
  });

  tearDown(() async {
    ApiClient.instance.dio.interceptors.remove(mock);
    await storage.clearSession();
  });

  Future<AuthResult> login({bool rememberMe = false}) =>
      AuthService.instance.login(
        email: 'customer@example.com',
        password: 'test-password',
        rememberMe: rememberMe,
      );

  test('inactive and admin accounts cannot save a session', () async {
    status = 'BLOCKED';
    await expectLater(login(), throwsA(isA<AuthException>()));
    expect(await storage.hasSession(), isFalse);
    status = 'ACTIVE';
    role = 'ADMIN';
    await expectLater(login(), throwsA(isA<AuthException>()));
    expect(await storage.hasSession(), isFalse);
  });

  test(
    'remember me controls persistence and logout ends the session',
    () async {
      const secure = FlutterSecureStorage();
      await login();
      expect(await storage.getToken(), 'test-session');
      expect(await secure.read(key: 'auth_session_v2'), isNull);
      await login(rememberMe: true);
      expect(await secure.read(key: 'auth_session_v2'), isNotNull);
      final ended = storage.sessionEnded.value;
      await AuthService.instance.logout();
      expect(await storage.hasSession(), isFalse);
      expect(await secure.read(key: 'auth_session_v2'), isNull);
      expect(storage.sessionEnded.value, ended + 1);
    },
  );
}
