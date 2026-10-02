import 'package:flutter/material.dart';
import 'package:yvenist/core/widgets/status_views.dart';

/// Notificações da conta. Ainda não há origem de notificações, então a tela
/// mostra o estado vazio real (o protótipo exibia notificações de exemplo
/// como se fossem do usuário).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const EmptyStateView(
        icon: Icons.notifications_none,
        title: 'Nenhuma notificação',
        message: 'Avisos sobre suas festas e orçamentos vão aparecer aqui.',
      ),
    );
  }
}
