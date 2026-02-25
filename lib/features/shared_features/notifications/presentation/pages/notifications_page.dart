import 'package:flutter/material.dart';
import '../../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../../core/theme/app_typography.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = [
      {
        'title': 'Promoção Relâmpago!',
        'body': 'Desconto de 20% no Salão Glamour apenas hoje.',
        'time': 'Há 2 min'
      },
      {
        'title': 'Pedido Confirmado',
        'body': 'Sua reserva para o dia 20/10 foi confirmada.',
        'time': 'Há 1 hora'
      },
      {
        'title': 'Novos Brinquedos',
        'body': 'Confira as novas opções de castelos infláveis.',
        'time': 'Ontem'
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notificações", style: AppTypography.sectionTitle),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            leading: const Icon(Icons.notifications, color: AppColors.primary),
            title: Text(item['title']!),
            subtitle: Text(item['body']!),
            trailing: Text(
              item['time']!,
              style: AppTypography.cardLocation.copyWith(fontSize: 10),
            ),
          );
        },
      ),
    );
  }
}