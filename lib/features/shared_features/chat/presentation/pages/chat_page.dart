import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/widgets/status_views.dart';

/// Aba de conversas. A troca de mensagens com fornecedores ainda não existe:
/// a tela diz isso com clareza, em vez de parecer uma caixa de entrada vazia.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensagens'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar ao início',
          onPressed: () => context.read<AppTabController>().goTo(AppTab.home),
        ),
      ),
      body: const EmptyStateView(
        icon: Icons.chat_bubble_outline,
        title: 'Conversas em breve',
        message: 'Aqui você vai falar direto com os fornecedores da sua festa.',
      ),
    );
  }
}
