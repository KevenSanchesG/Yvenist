import 'package:flutter/material.dart';
import 'package:yvenist/core/widgets/status_views.dart';

/// Formas de pagamento. O pagamento pelo app ainda não existe; a tela explica
/// como funciona hoje (o protótipo listava cartões de exemplo como se fossem
/// do usuário).
class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formas de Pagamento')),
      body: const EmptyStateView(
        icon: Icons.credit_card,
        title: 'Pagamento pelo app em breve',
        message: 'Por enquanto, você solicita o orçamento da festa e combina '
            'o pagamento direto com cada fornecedor.',
      ),
    );
  }
}
