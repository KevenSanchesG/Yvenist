import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/config_error_app.dart';
import 'package:yvenist/app/yvenist_app.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/licenses.dart';
import 'package:yvenist/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUi);
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
  final state = AppState(dependencies)..start();

  runApp(YvenistApp(dependencies: dependencies, state: state));
}
