import 'package:flutter/foundation.dart';

/// Configuração definida em tempo de build.
///
/// A URL da API vem de `--dart-define=API_BASE_URL=https://.../api/v1`. Sem
/// ela o app roda em **modo demonstração**: dados em memória, sem rede, igual
/// ao protótipo original. É o que permite abrir o app sem subir o backend.
class AppConfig {
  const AppConfig({this.apiBaseUrl});

  /// Lê a configuração do build. Lança [FormatException] se `API_BASE_URL`
  /// foi informada com um valor que não serve (veja [AppConfig.fromRaw]).
  factory AppConfig.fromEnvironment() {
    const raw = String.fromEnvironment('API_BASE_URL');
    return AppConfig.fromRaw(raw, isRelease: kReleaseMode);
  }

  /// Interpreta o valor de `API_BASE_URL`.
  ///
  /// Vazio é modo demonstração. Preenchido, precisa ser uma URL http(s)
  /// válida: um valor digitado errado não pode virar, em silêncio, um app
  /// publicado com dados de mentira.
  ///
  /// Em release ([isRelease]) a URL precisa ser https, porque senha e tokens
  /// passam por ela. A exceção é o próprio aparelho (`localhost`), cujo
  /// tráfego não sai para a rede.
  factory AppConfig.fromRaw(String raw, {required bool isRelease}) {
    if (raw.trim().isEmpty) return const AppConfig();

    final url = parseBaseUrl(raw);
    if (url == null) {
      throw FormatException(
        'API_BASE_URL inválida: "$raw". '
        'Use o endereço completo, como https://api.exemplo.com/api/v1.',
      );
    }
    if (isRelease && url.scheme != 'https' && !_isLoopback(url.host)) {
      throw FormatException(
        'Em builds de release a API_BASE_URL precisa usar https: "$raw".',
      );
    }
    return AppConfig(apiBaseUrl: url);
  }

  /// Mantida igual à do `pubspec.yaml` por um teste.
  static const String appVersion = '1.0.0';

  final Uri? apiBaseUrl;

  bool get isDemoMode => apiBaseUrl == null;

  /// Devolve `null` para vazio ou para algo que não seja uma URL http(s).
  static Uri? parseBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    // Sem barra no final: os caminhos das rotas já começam com "/".
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: path);
  }

  static bool _isLoopback(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}
