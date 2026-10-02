import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/vendor/onboarding/presentation/pages/hall_creation_flow_page.dart';

/// Escolha do que anunciar. Por enquanto só o fluxo de salão existe; as
/// outras opções aparecem como "Em breve" em vez de não responderem ao toque.
class AdCategorySelectionPage extends StatelessWidget {
  const AdCategorySelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('O que você vai anunciar?')),
      body: ListView(
        padding: context.withSystemBottomInset(const EdgeInsets.all(20)),
        children: [
          _CategoryCard(
            icon: Icons.home_work_outlined,
            title: 'Salão de Festas',
            subtitle: 'Sítios, salões, espaços gourmet, rooftops.',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const HallCreationFlowPage()),
            ),
          ),
          const _CategoryCard(
            icon: Icons.toys_outlined,
            title: 'Brinquedos e Atrações',
            subtitle: 'Pula-pula, piscina de bolinhas, animadores.',
          ),
          const _CategoryCard(
            icon: Icons.restaurant_menu,
            title: 'Buffet e Bar',
            subtitle: 'Salgados, bolos, bartender, churrasco.',
          ),
          const _CategoryCard(
            icon: Icons.celebration,
            title: 'Decoração',
            subtitle: 'Temas completos, pegue e monte, painéis.',
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// `null` = categoria ainda não disponível.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAvailable = onTap != null;
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          enabled: isAvailable,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: colors.surfaceMuted,
            child: Icon(
              icon,
              size: 28,
              color: isAvailable ? colors.primary : colors.textSecondary,
            ),
          ),
          title: Text(
            title,
            style: context.text.cardTitle.copyWith(
              color: isAvailable ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          subtitle: Text(subtitle, style: context.text.caption),
          trailing: isAvailable
              ? const Icon(Icons.arrow_forward_ios, size: 16)
              : Text('Em breve', style: context.text.caption),
        ),
      ),
    );
  }
}
