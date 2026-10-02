import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/party_status_presentation.dart';

/// Hub do Party Maker: as festas do usuário, para escolher qual abrir.
class MyPartiesPage extends StatelessWidget {
  const MyPartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final parties = controller.parties;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Festas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar ao início',
          onPressed: () => context.read<AppTabController>().goTo(AppTab.home),
        ),
      ),
      body: parties.isEmpty
          ? EmptyStateView(
              icon: Icons.cake_outlined,
              title: 'Você ainda não tem festas',
              message: 'Toque no + de um anúncio para começar a planejar.',
              actionLabel: 'Ver anúncios',
              onAction: () =>
                  context.read<AppTabController>().goTo(AppTab.home),
            )
          : RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: parties.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final party = parties[index];
                  return _PartyCard(
                    party: party,
                    isActive: party.id == controller.activePartyId,
                    // ✅ Seleciona e abre o Builder na mesma aba.
                    onTap: () => controller.setActiveParty(party.id),
                  );
                },
              ),
            ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.party,
    required this.isActive,
    required this.onTap,
  });

  final Party party;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemCount = party.budget.items.length;
    final summary = itemCount == 0
        ? 'Sem itens'
        : '$itemCount ${itemCount == 1 ? 'item' : 'itens'} • '
              '${formatBrl(party.budget.total.cents)}';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.primary : AppColors.divider,
          width: 1.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(party.title.value, style: AppTypography.cardTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              party.status.label,
              style: AppTypography.caption.copyWith(
                color: party.status.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(summary, style: AppTypography.caption),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
