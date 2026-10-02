import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_budget_item_view.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/party_budget_item_tile.dart';

/// Montagem de uma festa: itens escolhidos, total e pedido de orçamento.
class PartyBuilderPage extends StatelessWidget {
  const PartyBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final party = controller.activeParty;
    final items = controller.budgetItemViews;
    final isLocked = controller.isActivePartyLocked;

    return Scaffold(
      appBar: AppBar(
        title: Text(party?.title.value ?? 'Minha Festa'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar ao início',
          onPressed: () {
            controller.clearActiveParty();
            context.read<AppTabController>().goTo(AppTab.home);
          },
        ),
      ),
      body: party == null || items.isEmpty
          ? EmptyStateView(
              icon: Icons.cake_outlined,
              title: party == null
                  ? 'Nenhuma festa aberta'
                  : 'Sua festa está vazia',
              message: 'Toque no + de um anúncio para adicioná-lo à festa.',
              actionLabel: 'Ver anúncios',
              onAction: () =>
                  context.read<AppTabController>().goTo(AppTab.home),
            )
          : Column(
              children: [
                _Summary(itemCount: items.length, isLocked: isLocked),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return PartyBudgetItemTile(
                        item: item,
                        // Travada ou ocupada: o botão fica desabilitado, em
                        // vez de aceitar o toque e responder com um erro.
                        onRemove: isLocked || controller.isBusy
                            ? null
                            : () => _removeItem(
                                context,
                                item,
                                isLastItem: items.length == 1,
                              ),
                      );
                    },
                  ),
                ),
                _Footer(
                  totalCents: controller.activePartyTotalCents,
                  isLocked: isLocked,
                  isBusy: controller.isBusy,
                  onLock: () => _requestQuote(context),
                  onUnlock: () => _unlock(context),
                ),
              ],
            ),
    );
  }

  Future<void> _removeItem(
    BuildContext context,
    PartyBudgetItemView item, {
    required bool isLastItem,
  }) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    // Remover o último item apaga a festa: pede confirmação antes.
    if (isLastItem) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remover o último item?'),
          content: const Text(
            'Uma festa sem itens é apagada. Você pode criar outra depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover e apagar a festa'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final removed = await controller.removeItemFromActiveParty(item.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            removed
                ? '${item.name} removido.'
                : controller.error ?? 'Não foi possível remover o item.',
          ),
        ),
      );
  }

  Future<void> _requestQuote(BuildContext context) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    final locked = await controller.lockActivePartyForPayment();
    if (locked) controller.clearActiveParty();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            locked
                ? 'Orçamento solicitado! A festa fica travada enquanto isso.'
                : controller.error ?? 'Não foi possível solicitar o orçamento.',
          ),
        ),
      );
  }

  Future<void> _unlock(BuildContext context) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    final unlocked = await controller.unlockActiveParty();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            unlocked
                ? 'Festa liberada para edição.'
                : controller.error ?? 'Não foi possível liberar a festa.',
          ),
        ),
      );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.itemCount, required this.isLocked});

  final int itemCount;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              itemCount == 1
                  ? '1 item selecionado'
                  : '$itemCount itens selecionados',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (isLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.primaryStrong),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Orçamento solicitado',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.totalCents,
    required this.isLocked,
    required this.isBusy,
    required this.onLock,
    required this.onUnlock,
  });

  final int totalCents;
  final bool isLocked;
  final bool isBusy;
  final VoidCallback onLock;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      // A folga extra embaixo é do botão central da navegação, que sobe por
      // cima do fim desta aba: sem ela ele encobre a borda do botão do rodapé.
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + AppSpacing.navButtonOverlap,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Total',
                style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                formatBrl(totalCents),
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isBusy ? null : (isLocked ? onUnlock : onLock),
              child: isBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Text(isLocked ? 'Editar festa' : 'Solicitar orçamento'),
            ),
          ),
        ],
      ),
    );
  }
}
