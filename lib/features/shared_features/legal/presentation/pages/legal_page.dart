import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// Documentos legais do Yvenist.
///
/// Os textos ainda não foram redigidos. A tela lista os documentos previstos e
/// diz isso; redigir os termos é trabalho jurídico, não de código.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  static const List<({IconData icon, String title})> _documents = [
    (icon: Icons.description_outlined, title: 'Termos de Uso'),
    (icon: Icons.privacy_tip_outlined, title: 'Política de Privacidade'),
    (icon: Icons.gavel_outlined, title: 'Contrato do Fornecedor'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos e Política')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.headerBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Os documentos abaixo estão em elaboração e serão publicados '
              'aqui antes do lançamento.',
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: 16),
          for (final document in _documents)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.divider),
              ),
              child: ListTile(
                leading: Icon(document.icon, color: AppColors.primary),
                title: Text(document.title),
                subtitle: const Text('Em elaboração'),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Seus dados (LGPD)', style: AppTypography.sectionTitle),
          const SizedBox(height: 8),
          Text(
            'Você pode corrigir seus dados em Perfil > Dados Pessoais e apagar '
            'a conta, com tudo o que está ligado a ela, em Perfil > Segurança.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
