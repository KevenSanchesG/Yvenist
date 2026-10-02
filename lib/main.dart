import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_typography.dart';
import 'features/client/home/presentation/pages/home_client_page.dart';
import 'features/party_maker/presentation/party_maker_scope.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuração completa da UI do Sistema
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    // Barra de Status (Topo)
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,

    // Barra de Navegação (Fundo - Android)
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(
    PartyMakerScope(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yvenist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: AppTypography.fontFamily,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomeScreen(),
    );
  }
}
