/// Configuração definida em tempo de build.
///
/// A URL da API vem de `--dart-define=API_BASE_URL=https://.../api/v1`. Sem
/// ela o app roda em **modo demonstração**: dados em memória, sem rede, igual
/// ao protótipo original. É o que permite abrir o app sem subir o backend.
class AppConfig {
  const AppConfig({this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const raw = String.fromEnvironment('API_BASE_URL');
    return AppConfig(apiBaseUrl: parseBaseUrl(raw));
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
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    // Sem barra no final: os caminhos das rotas já começam com "/".
    final path = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(path: path);
  }
}
