import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// Um item da festa: o que é, como foi configurado, quanto se estima e o que
/// o fornecedor respondeu.
///
/// A estimativa e o orçamento aparecem em linhas separadas, cada uma com o
/// seu nome: uma é a conta do app, a outra é o valor que o fornecedor informou.
class PartyItemTile extends StatelessWidget {
  const PartyItemTile({
    super.key,
    required this.item,
    required this.budget,
    required this.guests,
    required this.onEdit,
    required this.onRemove,
    this.removeBlockedReason,
  });

  final PartyItem item;

  /// A composição da festa, para dizer a que outro item este está ligado.
  final PartyBudget budget;

  /// O número de convidados da festa: é com ele que se estima o que é cobrado
  /// por pessoa.
  final int? guests;

  /// `null` desabilita a ação (festa com o orçamento solicitado, ou uma
  /// operação em andamento).
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  /// Por que este item não pode sair sozinho (um serviço obrigatório). Aparece
  /// no lugar do rótulo de remover.
  final String? removeBlockedReason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final name = item.nameSnapshot;
    final relation = relationCaption(item, budget);
    final summary = configurationSummary(
      spec: item.spec,
      configuration: item.configuration,
      quantity: item.quantity.value,
    );
    final notes = item.configuration[ItemConfiguration.notesKey];
    final isAvailable = item.externalRef.isAvailable;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.quote.needsTheClient ? colors.warning : colors.divider,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppNetworkImage(
              url: item.imageUrlSnapshot,
              width: 56,
              height: 56,
              fallbackIcon: item.category.icon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.cardTitle.copyWith(fontSize: 14)),
                if (relation != null) Text(relation, style: text.caption),
                if (summary.isNotEmpty)
                  Text(summary.join(' · '), style: text.caption),
                if (notes is String)
                  Text(
                    'Obs.: $notes',
                    style: text.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (!isAvailable)
                  Text(
                    'Este anúncio saiu do catálogo. Remova o item para '
                    'solicitar o orçamento.',
                    style: text.caption.copyWith(color: colors.danger),
                  ),
                const SizedBox(height: 6),
                _Amount(
                  label: 'Estimativa',
                  value: amountLabel(item.estimate(guests: guests)),
                  detail: pricingBasis(item.pricing),
                ),
                if (item.quote.status != QuoteStatus.none)
                  _QuoteLine(quote: item.quote),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Alterar $name',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: colors.danger,
                tooltip: removeBlockedReason ?? 'Remover $name',
                onPressed: removeBlockedReason == null ? onRemove : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Estimativa: R$ 4.400,00 (R$ 55 por pessoa)": o valor e, quando há uma, a
/// conta por trás dele.
class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final showDetail = detail != null;

    return Text.rich(
      TextSpan(
        style: text.caption,
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: context.colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showDetail) TextSpan(text: ' ($detail)'),
        ],
      ),
    );
  }
}

/// O que o fornecedor respondeu sobre o item.
class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.quote});

  final ItemQuote quote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final color = quote.status.colorIn(colors);
    final amount = quote.amount;
    final message = quote.message;
    final label = quote.isQuoted && amount != null
        ? 'Orçamento: ${amountLabel(amount)}'
        : quote.status.label!;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) Text('"$message"', style: text.caption),
        ],
      ),
    );
  }
}
