import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/config_error_app.dart';
import 'package:yvenist/app/yvenist_app.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerThirdPartyLicenses();

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
