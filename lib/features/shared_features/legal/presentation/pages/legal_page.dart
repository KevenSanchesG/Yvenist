import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/shared_features/legal/domain/legal_document.dart';
import 'package:yvenist/features/shared_features/legal/presentation/pages/legal_document_page.dart';
import 'package:yvenist/features/shared_features/legal/presentation/widgets/draft_notice.dart';

/// Documentos legais do Yvenist.
///
/// Os Termos de Uso e a Política de Privacidade existem como versão
/// preliminar (veja [LegalDocument]). O Contrato do Fornecedor ainda não foi
/// escrito: as regras para fornecedores estão, por enquanto, nos Termos de Uso.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  void _open(BuildContext context, LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termos e Política')),
      body: ListView(
        padding: context.withSystemBottomInset(const EdgeInsets.all(20)),
        children: [
          const DraftNotice(),
          const SizedBox(height: 16),
          _DocumentTile(
            icon: Icons.description_outlined,
            title: LegalDocument.termsOfUse.title,
            onTap: () => _open(context, LegalDocument.termsOfUse),
          ),
          _DocumentTile(
            icon: Icons.privacy_tip_outlined,
            title: LegalDocument.privacyPolicy.title,
            onTap: () => _open(context, LegalDocument.privacyPolicy),
          ),
          const _DocumentTile(
            icon: Icons.gavel_outlined,
            title: 'Contrato do Fornecedor',
          ),
          const SizedBox(height: 8),
          Text('Seus dados (LGPD)', style: context.text.sectionTitle),
          const SizedBox(height: 8),
          Text(
            'Você pode corrigir seus dados em Perfil > Dados Pessoais e apagar '
            'a conta, com tudo o que está ligado a ela, em Perfil > Segurança.',
            style: context.text.body.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Um documento da lista. Sem [onTap] o documento ainda não existe.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAvailable = onTap != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colors.divider),
      ),
      child: ListTile(
        leading: Icon(icon, color: context.colors.primary),
        title: Text(title),
        subtitle: Text(isAvailable ? 'Versão preliminar' : 'Em elaboração'),
        trailing: isAvailable ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}
