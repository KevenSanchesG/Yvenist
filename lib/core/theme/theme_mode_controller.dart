import 'package:flutter/material.dart';
import 'package:yvenist/core/storage/theme_preference_storage.dart';

/// O tema que a pessoa escolheu: claro, escuro ou o do aparelho.
///
/// Sem escolha nenhuma vale o do aparelho. A troca aparece na hora e é
/// guardada para a próxima vez que o app abrir.
class ThemeModeController extends ChangeNotifier {
  ThemeModeController(this._storage);

  final ThemePreferenceStorage _storage;

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;
  bool _selected = false;
  bool _disposed = false;

  ThemeMode get mode => _mode;

  /// Lê a escolha guardada. Chamado uma vez, antes de a primeira tela
  /// aparecer, para o app já abrir no tema certo.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final stored = await _storage.read();
    // Uma escolha feita enquanto a leitura não voltava vale mais que ela.
    if (_selected || stored == null || stored == _mode) return;
    _mode = stored;
    _notify();
  }

  Future<void> select(ThemeMode mode) async {
    _selected = true;
    if (mode == _mode) return;
    _mode = mode;
    _notify();
    await _storage.write(mode);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
