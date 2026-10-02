import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/storage/theme_preference_storage.dart';
import 'package:yvenist/core/storage/token_storage.dart';

/// A raiz de composição, usada fora de uma tela.
///
/// De propósito, este arquivo não inicializa o Flutter (não há `testWidgets`
/// nem `ensureInitialized`): é assim que os testes de integração montam o
/// app, e é onde um acesso indevido ao aparelho aparece.
void main() {
  final config = AppConfig(apiBaseUrl: Uri.parse('http://127.0.0.1:1/api/v1'));

  /// Uma rede que não responde a nada: o que importa aqui é abrir o app.
  http.Client offline() {
    return MockClient((request) async => http.Response('', 503));
  }

  test('montado pela API sem dizer onde guardar o tema, o app abre sem tocar '
      'no aparelho', () async {
    // Regressão: `AppDependencies.api` passou a guardar a escolha de tema no
    // aparelho quando nada era informado. Montado em um teste sem tela, como
    // nos de integração, abrir o app lançava "Binding has not yet been
    // initialized", e todos os testes de integração falharam no CI.
    final dependencies = AppDependencies.api(
      config,
      httpClient: offline(),
      tokenStorage: InMemoryTokenStorage(),
    );
    final state = AppState(dependencies);
    addTearDown(state.dispose);

    await state.start();

    expect(state.theme.mode, ThemeMode.system);
    expect(
      dependencies.themePreferences,
      isA<InMemoryThemePreferenceStorage>(),
    );
  });

  test('a escolha de tema guardada vale para o app montado pela API', () async {
    final dependencies = AppDependencies.api(
      config,
      httpClient: offline(),
      tokenStorage: InMemoryTokenStorage(),
      themePreferences: InMemoryThemePreferenceStorage(ThemeMode.dark),
    );
    final state = AppState(dependencies);
    addTearDown(state.dispose);

    await state.start();

    expect(state.theme.mode, ThemeMode.dark);
  });

  test('o app de verdade guarda a escolha de tema no aparelho, nos dois '
      'modos', () {
    for (final appConfig in [const AppConfig(), config]) {
      final dependencies = AppDependencies.fromConfig(appConfig);

      expect(
        dependencies.themePreferences,
        isA<DeviceThemePreferenceStorage>(),
        reason: appConfig.isDemoMode ? 'modo demonstração' : 'com a API',
      );
    }
  });
}
