import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onde a escolha de tema (claro, escuro ou o do aparelho) fica guardada entre
/// execuções do app. É uma preferência do aparelho, e não da conta: vale
/// também para quem não entrou, e não vai para o servidor.
abstract interface class ThemePreferenceStorage {
  /// A escolha guardada, ou `null` se a pessoa nunca escolheu.
  Future<ThemeMode?> read();

  Future<void> write(ThemeMode mode);
}

/// Guarda a escolha no aparelho.
///
/// Usa o mesmo pacote que guarda os tokens da sessão, para o app não ganhar
/// mais uma dependência só por causa de um valor. A escolha de tema não é um
/// segredo: o cofre aqui é só o lugar de guardar.
class DeviceThemePreferenceStorage implements ThemePreferenceStorage {
  DeviceThemePreferenceStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'yvenist.theme_mode';

  final FlutterSecureStorage _storage;

  // Nenhuma falha daqui pode passar adiante: a leitura acontece antes da
  // primeira tela, e um erro ali impediria o app de abrir. Na web fora de um
  // contexto seguro (uma página em `http` que não é `localhost`) o pacote
  // lança `UnsupportedError`, que não é uma `Exception`.

  @override
  Future<ThemeMode?> read() async {
    try {
      final value = await _storage.read(key: _key);
      return ThemeMode.values.asNameMap()[value];
    } on Exception {
      // Sem conseguir ler (o cofre do sistema pode falhar), o app abre no
      // tema do aparelho, como se a pessoa nunca tivesse escolhido.
      return null;
    } on UnsupportedError {
      return null;
    }
  }

  @override
  Future<void> write(ThemeMode mode) async {
    try {
      await _storage.write(key: _key, value: mode.name);
    } on Exception {
      // Sem conseguir gravar, a escolha vale até o app fechar.
    } on UnsupportedError {
      // Idem.
    }
  }
}

/// Mantém a escolha só em memória: testes.
class InMemoryThemePreferenceStorage implements ThemePreferenceStorage {
  InMemoryThemePreferenceStorage([this._mode]);

  ThemeMode? _mode;

  @override
  Future<ThemeMode?> read() async => _mode;

  @override
  Future<void> write(ThemeMode mode) async => _mode = mode;
}
