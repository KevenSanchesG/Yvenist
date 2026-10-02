import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';

/// Mostrada no lugar do app quando o build foi configurado errado (por
/// exemplo, uma `API_BASE_URL` inválida).
///
/// É um erro de quem gerou o build, não de quem usa: a tela existe para ele
/// ser percebido na primeira execução, em vez de o app abrir em branco ou
/// rodar com dados de demonstração sem ninguém notar.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yvenist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: EmptyStateView(
            icon: Icons.build_circle_outlined,
            title: 'App configurado incorretamente',
            message: message,
          ),
        ),
      ),
    );
  }
}
