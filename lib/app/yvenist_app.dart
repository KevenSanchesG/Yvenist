import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_shell.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// Raiz do app: disponibiliza as dependências para as telas e define tema,
/// idioma e a tela inicial.
class YvenistApp extends StatelessWidget {
  const YvenistApp({
    super.key,
    required this.dependencies,
    required this.state,
  });

  final AppDependencies dependencies;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: dependencies.config),
        Provider<CatalogRepository>.value(value: dependencies.catalog),
        // .value: os controllers pertencem ao AppState, que os descarta.
        ChangeNotifierProvider.value(value: state.session),
        ChangeNotifierProvider.value(value: state.tabs),
        ChangeNotifierProvider.value(value: state.favorites),
        ChangeNotifierProvider.value(value: state.parties),
        ChangeNotifierProvider.value(value: state.vendor),
      ],
      child: MaterialApp(
        title: 'Yvenist',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // O app é em português: datas, botões padrão e leitores de tela
        // seguem o idioma.
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AppShell(),
      ),
    );
  }
}
