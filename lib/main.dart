import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/yvenist_app.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUi);

  // Sem --dart-define=API_BASE_URL o app roda em modo demonstração.
  final dependencies = AppDependencies.fromConfig(AppConfig.fromEnvironment());
  final state = AppState(dependencies)..start();

  runApp(YvenistApp(dependencies: dependencies, state: state));
}
