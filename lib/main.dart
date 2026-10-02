import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/config_error_app.dart';
import 'package:yvenist/app/yvenist_app.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();
  _drawBehindSystemBars();

  // Sem --dart-define=API_BASE_URL o app roda em modo demonstração.
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on FormatException catch (error) {
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  final dependencies = AppDependencies.fromConfig(config);
  final state = AppState(dependencies);
  // Antes da primeira tela: o app já abre no tema que a pessoa escolheu, sem
  // piscar no outro. A sessão é recuperada depois, com a tela já no ar.
  await state.theme.load();
  unawaited(state.start());

  runApp(YvenistApp(dependencies: dependencies, state: state));
}

/// Pede ao Android para o app desenhar a tela inteira, inclusive por baixo da
/// barra de status e da barra de navegação do sistema.
///
/// A partir do Android 15 o sistema impõe isso a um app que mira a API 35 ou
/// mais nova. Pedir o mesmo nas versões anteriores faz o app ter um leiaute
/// só: o que é conferido em uma versão vale para as outras. No Android 9 ou
/// mais antigo o pedido não tem efeito (`AppTheme.systemUi` cuida desse caso);
/// no iOS já é assim.
void _drawBehindSystemBars() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
}
