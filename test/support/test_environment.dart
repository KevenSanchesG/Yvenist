import 'test_environment_io.dart'
    if (dart.library.js_interop) 'test_environment_web.dart'
    as platform;

/// Os mesmos nomes, quando passados com `--dart-define` (obrigatório no
/// navegador, opcional fora dele).
const Map<String, String> _defines = {
  'YVENIST_API_URL': String.fromEnvironment('YVENIST_API_URL'),
  'YVENIST_ADMIN_EMAIL': String.fromEnvironment('YVENIST_ADMIN_EMAIL'),
  'YVENIST_ADMIN_PASSWORD': String.fromEnvironment('YVENIST_ADMIN_PASSWORD'),
};

/// Configuração dos testes de integração.
///
/// Rodando na máquina, vem das variáveis de ambiente. Rodando dentro do
/// navegador (`flutter test --platform chrome`) não existem variáveis de
/// ambiente, e os valores chegam por `--dart-define=NOME=valor`.
String? testEnvironment(String name) {
  final defined = _defines[name];
  if (defined != null && defined.isNotEmpty) return defined;
  return platform.environmentVariable(name);
}
