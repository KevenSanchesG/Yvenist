import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Formas de Pagamento"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PaymentCard(type: "Mastercard", lastDigits: "8829", isDefault: true),
          _PaymentCard(type: "Visa", lastDigits: "4021", isDefault: false),
          _PaymentCard(type: "Pix", lastDigits: "aleatória", isDefault: false, isPix: true),
          
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text("Adicionar novo método"),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
          )
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String type;
  final String lastDigits;
  final bool isDefault;
  final bool isPix;

  const _PaymentCard({required this.type, required this.lastDigits, required this.isDefault, this.isPix = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(isPix ? Icons.qr_code : Icons.credit_card, color: AppColors.primary),
        title: Text(isPix ? "Chave Pix" : "$type •••• $lastDigits"),
        subtitle: isDefault ? const Text("Padrão", style: TextStyle(color: Colors.green)) : null,
        trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
      ),
    );
  }
}