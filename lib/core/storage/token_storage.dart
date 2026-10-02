import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Par de tokens de uma sessão autenticada.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }

  final String accessToken;
  final String refreshToken;
}

/// Onde os tokens da sessão ficam guardados entre execuções do app.
abstract interface class TokenStorage {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Guarda os tokens no cofre do sistema (Keystore no Android, Keychain no iOS).
/// Nunca em `SharedPreferences`: lá ficariam em texto puro.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'yvenist.access_token';
  static const _refreshKey = 'yvenist.refresh_token';

  final FlutterSecureStorage _storage;

  // Evita ir ao canal nativo a cada requisição.
  AuthTokens? _cached;
  bool _loaded = false;

  @override
  Future<AuthTokens?> read() async {
    if (_loaded) return _cached;

    final accessToken = await _storage.read(key: _accessKey);
    final refreshToken = await _storage.read(key: _refreshKey);
    _cached = (accessToken != null && refreshToken != null)
        ? AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
        : null;
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    _cached = tokens;
    _loaded = true;
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Mantém os tokens só em memória: modo demonstração e testes.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
