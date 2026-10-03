import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/app_network_image.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/presentation/add_to_party_flow.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_target.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// Os parceiros que um item da festa recomenda e que ainda não estão nela.
///
/// É uma indicação, e não um pacote: cada parceiro é um anúncio à parte, que a
/// pessoa configura e contrata por conta própria. Sem parceiros para sugerir
/// (ou sem conseguir consultar o catálogo) o bloco não aparece: a festa não
/// depende dele.
class PartnerSuggestions extends StatefulWidget {
  const PartnerSuggestions({
    super.key,
    required this.party,
    required this.item,
    required this.isEnabled,
  });

  final Party party;

  /// O item que recomenda. Tem de ser um anúncio do catálogo.
  final PartyItem item;

  /// Falso enquanto uma operação está em andamento.
  final bool isEnabled;

  @override
  State<PartnerSuggestions> createState() => _PartnerSuggestionsState();
}

class _PartnerSuggestionsState extends State<PartnerSuggestions>
    with AutomaticKeepAliveClientMixin {
  List<PartyItemDraft> _partners = const [];

  // A lista da festa desmonta o que sai da tela ao rolar. Mantido vivo, o
  // bloco consulta o catálogo uma vez só por visita à festa.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final draft = await context.read<PartyItemCatalog>().draftFor(
        widget.item.externalRef.id,
      );
      if (mounted) setState(() => _partners = draft.partners);
    } catch (_) {
      // O anúncio saiu do catálogo, ou não deu para consultar: sem sugestões.
    }
  }

  void _add(PartyItemDraft partner) {
    configureAndAddToParty(
      context,
      listingId: partner.externalRef.id,
      itemName: partner.name,
      target: ExistingPartyTarget(widget.party.id),
      recommendedBy: widget.item.id,
      fromParty: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final budget = widget.party.budget;
    final pending = [
      for (final partner in _partners)
        if (budget.findByExternalRef(partner.externalRef) == null) partner,
    ];
    if (pending.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final text = context.text;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Recomendados por ${widget.item.nameSnapshot}',
              style: text.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Cada um é contratado à parte, com o orçamento dele.',
            style: text.caption,
          ),
          for (final partner in pending)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppNetworkImage(
                      url: partner.imageUrl,
                      width: 40,
                      height: 40,
                      fallbackIcon: partner.category.icon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partner.name, style: text.body),
                        Text(
                          '${partner.category.groupLabel} · '
                          '${pricingLabel(partner.pricing)}',
                          style: text.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: colors.primary,
                    tooltip: 'Adicionar ${partner.name} à festa',
                    onPressed: widget.isEnabled ? () => _add(partner) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
