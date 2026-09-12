import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage so the rest of the app never talks to
/// storage directly — makes it easy to swap storage strategy later.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  final _storage = const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _nameKey = 'auth_name';
  static const _emailKey = 'auth_email';

  Future<void> saveSession({
    required String token,
    required String role,
    required String fullName,
    required String email,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _nameKey, value: fullName);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<void> updateIdentity({
    required String fullName,
    required String email,
  }) async {
    await _storage.write(key: _nameKey, value: fullName);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);
  Future<String?> getFullName() => _storage.read(key: _nameKey);
  Future<String?> getEmail() => _storage.read(key: _emailKey);

  Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
