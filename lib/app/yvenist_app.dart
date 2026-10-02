import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_shell.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/theme/theme_mode_controller.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
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
        Provider<ReviewRepository>.value(value: dependencies.reviews),
        // .value: os controllers pertencem ao AppState, que os descarta.
        ChangeNotifierProvider.value(value: state.theme),
        ChangeNotifierProvider.value(value: state.session),
        ChangeNotifierProvider.value(value: state.tabs),
        ChangeNotifierProvider.value(value: state.favorites),
        ChangeNotifierProvider.value(value: state.parties),
        ChangeNotifierProvider.value(value: state.vendor),
      ],
      // Só o MaterialApp ouve a escolha de tema: trocá-la refaz o tema, e as
      // telas mudam de cor por herança, com a animação do próprio Material.
      child: Consumer<ThemeModeController>(
        builder: (context, theme, child) => MaterialApp(
          title: 'Yvenist',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: theme.mode,
          // O app é em português: datas, botões padrão e leitores de tela
          // seguem o idioma.
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: AppTheme.systemBars,
          home: child,
        ),
        child: const AppShell(),
      ),
    );
  }
}
