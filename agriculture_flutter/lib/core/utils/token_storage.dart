import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _sessionKey = 'auth_session_v2';

  // Previous implementation's keys.
  static const _legacyKeys = [
    'auth_token',
    'auth_role',
    'auth_name',
    'auth_email',
  ];

  final ValueNotifier<int> sessionEnded = ValueNotifier<int>(0);

  Map<String, String>? _session;
  bool _rememberMe = false;
  bool _loaded = false;
  Future<void>? _loading;

  Future<void> _operations = Future<void>.value();

  int _version = 0;
  int get version => _version;

  Future<void> initialize() async {
    if (_loaded) return;

    final pending = _loading;
    if (pending != null) {
      await pending;
      return;
    }

    final operation = _load();
    _loading = operation;

    try {
      await operation;
      _loaded = true;
    } finally {
      _loading = null;
    }
  }

  Future<void> _load() async {
    final raw = await _storage.read(key: _sessionKey);

    if (raw != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final session = decoded.map(
          (key, value) => MapEntry(key, value as String),
        );

        if ((session['token'] ?? '').isEmpty ||
            session['role'] == null ||
            session['fullName'] == null ||
            session['email'] == null) {
          throw const FormatException('Invalid saved session');
        }

        _session = session;
        _rememberMe = true;
      } on FormatException {
        await _storage.delete(key: _sessionKey);
      } on TypeError {
        await _storage.delete(key: _sessionKey);
      }
    }

    // Old sessions did not record Remember Me consent.
    // Require one fresh login after this upgrade.
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operations.then((_) => action());

    // A failed operation must not block later retries.
    _operations = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );

    return next;
  }

  Future<void> saveSession({
    required String token,
    required String role,
    required String fullName,
    required String email,
    bool rememberMe = false,
  }) async {
    await initialize();

    await _serialize(() async {
      final session = <String, String>{
        'token': token,
        'role': role,
        'fullName': fullName,
        'email': email,
      };

      if (rememberMe) {
        await _storage.write(key: _sessionKey, value: jsonEncode(session));
      } else {
        await _storage.delete(key: _sessionKey);
      }

      _session = session;
      _rememberMe = rememberMe;
      _version++;
    });
  }

  Future<void> updateIdentity({
    required String fullName,
    required String email,
  }) async {
    await initialize();
    final expectedVersion = _version;

    await _serialize(() async {
      if (_session == null || _version != expectedVersion) return;

      final updated = <String, String>{
        ..._session!,
        'fullName': fullName,
        'email': email,
      };

      if (_rememberMe) {
        await _storage.write(key: _sessionKey, value: jsonEncode(updated));
      }

      _session = updated;
    });
  }

  Future<String?> getToken() async {
    await initialize();
    return _session?['token'];
  }

  Future<String?> getRole() async {
    await initialize();
    return _session?['role'];
  }

  Future<String?> getFullName() async {
    await initialize();
    return _session?['fullName'];
  }

  Future<String?> getEmail() async {
    await initialize();
    return _session?['email'];
  }

  Future<bool> hasSession() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession({int? expectedVersion}) async {
    await initialize();

    await _serialize(() async {
      // Ignore an old request's failure after another login.
      if (expectedVersion != null && expectedVersion != _version) return;

      await _storage.delete(key: _sessionKey);

      final hadSession = _session != null;
      _session = null;
      _rememberMe = false;
      _version++;

      if (hadSession) {
        sessionEnded.value++;
      }
    });
  }
}
