import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_palette.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/core/widgets/system_insets.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// O que aconteceu com a festa desde que o orçamento foi pedido: cada pedido,
/// cada resposta de fornecedor e cada volta para a edição, do mais novo para o
/// mais antigo.
class PartyHistoryPage extends StatelessWidget {
  const PartyHistoryPage({super.key, required this.partyId});

  final PartyId partyId;

  @override
  Widget build(BuildContext context) {
    // Lê do controller, e não de uma cópia: uma resposta que chega enquanto a
    // tela está aberta aparece aqui.
    final party = context.watch<PartyMakerController>().partyById(partyId);
    final entries = party?.history.reversed.toList() ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Histórico da festa')),
      body: entries.isEmpty
          ? const EmptyStateView(
              icon: Icons.history,
              title: 'Nada por aqui ainda',
              message:
                  'O histórico começa quando você solicita o orçamento. Cada '
                  'pedido, resposta e alteração fica registrado aqui.',
            )
          : ListView.separated(
              padding: context.withSystemBottomInset(const EdgeInsets.all(16)),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (_, index) => _HistoryTile(entry: entries[index]),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final PartyHistoryEntry entry;

  Color _colorIn(AppPalette colors) => switch (entry.kind) {
    PartyHistoryKind.vendorQuoted ||
    PartyHistoryKind.confirmed => colors.success,
    PartyHistoryKind.vendorRequestedChanges => colors.warning,
    PartyHistoryKind.vendorDeclined ||
    PartyHistoryKind.cancelled => colors.danger,
    PartyHistoryKind.quoteRequested ||
    PartyHistoryKind.reopened => colors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final message = entry.message;
    final amount = historyAmountCaption(entry);
    final round = entry.round > 0 ? ' · ${entry.round}ª rodada' : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(entry.kind.icon, size: 22, color: _colorIn(colors)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                describeHistoryEntry(entry),
                style: text.body.copyWith(fontWeight: FontWeight.w600),
              ),
              if (message != null) ...[
                const SizedBox(height: 2),
                Text('"$message"', style: text.body),
              ],
              if (amount != null) Text(amount, style: text.caption),
              const SizedBox(height: 2),
              Text('${formatEventDate(entry.at)}$round', style: text.caption),
            ],
          ),
        ),
      ],
    );
  }
}
