import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/pages/event_details_page.dart';
import 'package:yvenist/features/party_maker/presentation/pages/item_configuration_page.dart';
import 'package:yvenist/features/party_maker/presentation/pages/party_history_page.dart';
import 'package:yvenist/features/party_maker/presentation/pages/quote_inbox_page.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/event_type_name.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/partner_suggestions.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/party_item_tile.dart';

/// A festa aberta: o evento, o que já foi escolhido, quanto se estima, o que
/// os fornecedores responderam e qual é o próximo passo.
///
/// A tela só mostra e dispara: o que pode ou não ser feito vem do agregado
/// (`Party`), e cada ação é uma operação do controller.
class PartyBuilderPage extends StatelessWidget {
  const PartyBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final party = controller.activeParty;

    // Quem decide abrir esta tela (`PartyMakerEntryPage`) só o faz com uma
    // festa aberta. Se ela sumir entre um quadro e outro, nada é desenhado.
    if (party == null) return const SizedBox.shrink();

    final isEditable = party.status.isEditable;
    final isBusy = controller.isBusy;
    final items = party.budget.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(party.title.value),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar para as festas',
          onPressed: controller.clearActiveParty,
        ),
        // Dois botões, e não mais: com três o nome da festa não cabia no
        // título, e é ele que diz o que a pessoa está montando.
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar a festa',
            onPressed: isBusy ? null : () => _refresh(context),
          ),
          _PartyMenu(
            party: party,
            onHistory: () =>
                _push(context, PartyHistoryPage(partyId: party.id)),
            onEditEvent: () => _editEvent(context, party),
            onCancel: () => _cancel(context, party),
            onDelete: () => _delete(context, party),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(context),
              child: ListView(
                // Rola mesmo com pouco conteúdo: é o que permite puxar a tela
                // para atualizar.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _StatusBanner(
                    party: party,
                    onAnswerAsVendor: _canAnswerAsVendor(context, party)
                        ? () => _answerAsVendor(context)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _EventSummary(
                    party: party,
                    onEdit: isEditable && !isBusy
                        ? () => _editEvent(context, party)
                        : null,
                  ),
                  if (isEditable && items.isNotEmpty)
                    _Pendencies(
                      blockers: party.quoteBlockers,
                      onFixEvent: () => _editEvent(context, party),
                    ),
                  if (items.isEmpty)
                    _NoItems(canAdd: isEditable)
                  else
                    for (final category in partyCategoryOrder)
                      ..._group(context, party, category, isBusy: isBusy),
                ],
              ),
            ),
          ),
          _Footer(
            party: party,
            isBusy: isBusy,
            onRequestQuote: () => _requestQuote(context, party),
            onReopen: () => _reopen(context, party),
            onConfirm: () => _confirm(context, party),
          ),
        ],
      ),
    );
  }

  /// Os itens de uma categoria, com o título do grupo. Nada, se a festa não
  /// tem item dela.
  List<Widget> _group(
    BuildContext context,
    Party party,
    PartyItemCategory category, {
    required bool isBusy,
  }) {
    final items = [
      for (final item in party.budget.items)
        if (item.category == category) item,
    ];
    if (items.isEmpty) return const [];

    final isEditable = party.status.isEditable;
    final canChange = isEditable && !isBusy;
    return [
      _GroupTitle(category: category),
      for (final item in items) ...[
        PartyItemTile(
          item: item,
          budget: party.budget,
          guests: party.guestCount?.value,
          onEdit: canChange ? () => _editItem(context, party, item) : null,
          onRemove: canChange ? () => _removeItem(context, party, item) : null,
          removeBlockedReason: _removeBlockedReason(party, item),
        ),
        // Só um anúncio escolhido por conta própria indica parceiros: um item
        // ligado a outro não tem itens ligados a ele.
        if (isEditable &&
            item.externalRef.isListing &&
            item.relation.parentId == null)
          PartnerSuggestions(
            key: ValueKey('partners-${item.id.value}'),
            party: party,
            item: item,
            isEnabled: !isBusy,
          ),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// Um serviço obrigatório não sai sozinho: o botão fica desabilitado e diz
  /// por quê, em vez de aceitar o toque e responder com um erro.
  String? _removeBlockedReason(Party party, PartyItem item) {
    final parentId = item.relation.parentId;
    if (!item.relation.isRequired || parentId == null) return null;
    final parent = party.budget.findById(parentId);
    if (parent == null) return null;
    return '${item.nameSnapshot} é obrigatório com ${parent.nameSnapshot}';
  }

  // ------------------------------------------------------------------
  // Ações
  // ------------------------------------------------------------------

  void _push(BuildContext context, Widget page) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
  }

  /// Busca a festa de novo. É como a pessoa vê o que os fornecedores
  /// responderam: não há aviso automático.
  Future<void> _refresh(BuildContext context) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    await controller.load();
    final error = controller.loadError;
    if (error != null) _notify(messenger, error);
  }

  void _editEvent(BuildContext context, Party party) {
    _push(context, EventDetailsPage.edit(partyId: party.id));
  }

  Future<void> _editItem(
    BuildContext context,
    Party party,
    PartyItem item,
  ) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemConfigurationPage.edit(
          partyId: party.id,
          itemId: item.id,
          itemName: item.nameSnapshot,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      showAppSnackBar(context, '${item.nameSnapshot} atualizado.');
    }
  }

  Future<void> _removeItem(
    BuildContext context,
    Party party,
    PartyItem item,
  ) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);
    final name = item.nameSnapshot;

    // O que sai junto e o que fica solto é dito antes: nada some em silêncio.
    final impact = party.budget.removalOf(item.id);
    final leaving = [
      for (final other in impact.removedWith) other.nameSnapshot,
    ];
    final staying = [for (final other in impact.released) other.nameSnapshot];
    final confirmed = await _confirmDialog(
      context,
      title: 'Remover $name?',
      message: [
        'O que você informou para este item será perdido.',
        if (leaving.isNotEmpty)
          'Também ${leaving.length == 1 ? 'sai' : 'saem'} da festa: '
              '${leaving.join(', ')}.',
        if (staying.isNotEmpty)
          '${staying.join(', ')} '
              '${staying.length == 1 ? 'continua' : 'continuam'} na festa.',
      ].join('\n\n'),
      action: 'Remover',
    );
    if (!confirmed) return;

    final removal = await controller.removeItem(party.id, item.id);
    if (removal == null) {
      _notify(
        messenger,
        controller.error ?? 'Não foi possível remover o item.',
      );
      return;
    }
    final also = [for (final other in removal.removedWith) other.nameSnapshot];
    _notify(
      messenger,
      also.isEmpty
          ? '$name removido.'
          : '$name removido, com ${also.join(', ')}.',
    );
  }

  Future<void> _requestQuote(BuildContext context, Party party) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    // A pessoa fica sabendo o que acontece, e o que é enviado, antes de pedir.
    final confirmed = await _confirmDialog(
      context,
      title: 'Solicitar orçamento?',
      message:
          'Cada fornecedor recebe o pedido do item dele, com o tipo de '
          'evento, a data, o número de convidados e o que você informou no '
          'item. Seu nome e o nome da festa não são enviados.\n\n'
          'A festa fica travada até você voltar a editar.',
      action: 'Solicitar',
    );
    if (!confirmed) return;

    final requested = await controller.requestQuote(party.id);
    _notify(
      messenger,
      requested
          ? 'Orçamento solicitado. As respostas dos fornecedores aparecem '
                'aqui.'
          : controller.error ?? 'Não foi possível solicitar o orçamento.',
    );
  }

  Future<void> _reopen(BuildContext context, Party party) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    if (party.status == PartyStatus.confirmed) {
      final confirmed = await _confirmDialog(
        context,
        title: 'Editar a festa?',
        message:
            'Você já aceitou este orçamento. Editar a festa desfaz o aceite, e '
            'o que você alterar precisa de um novo valor do fornecedor.',
        action: 'Editar festa',
      );
      if (!confirmed) return;
    }

    final reopened = await controller.reopen(party.id);
    _notify(
      messenger,
      reopened
          ? 'Festa liberada para edição.'
          : controller.error ?? 'Não foi possível liberar a festa.',
    );
  }

  Future<void> _confirm(BuildContext context, Party party) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);
    final total = party.quotedTotal;

    final confirmed = await _confirmDialog(
      context,
      title: 'Aceitar o orçamento?',
      // "Aparece na lista", e não "eles ficam sabendo": o app não avisa
      // ninguém, e a pessoa não deve contar com um aviso que não existe.
      message:
          'O total informado pelos fornecedores é '
          '${total == null ? onRequestLabel : formatBrl(total.cents)}. O '
          'aceite aparece para eles na lista de pedidos.\n\n'
          'O pagamento é combinado direto com cada fornecedor.',
      action: 'Aceitar',
    );
    if (!confirmed) return;

    final accepted = await controller.confirmQuote(party.id);
    _notify(
      messenger,
      accepted
          ? 'Orçamento aceito.'
          : controller.error ?? 'Não foi possível aceitar o orçamento.',
    );
  }

  Future<void> _cancel(BuildContext context, Party party) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await _confirmDialog(
      context,
      title: 'Cancelar esta festa?',
      message:
          'O cancelamento aparece para os fornecedores na lista de pedidos '
          'deles. A festa continua na sua lista, como cancelada, e não pode '
          'mais ser alterada.',
      action: 'Cancelar a festa',
      dismiss: 'Manter a festa',
    );
    if (!confirmed) return;

    final cancelled = await controller.cancelParty(party.id);
    _notify(
      messenger,
      cancelled
          ? 'Festa cancelada.'
          : controller.error ?? 'Não foi possível cancelar a festa.',
    );
  }

  Future<void> _delete(BuildContext context, Party party) async {
    final controller = context.read<PartyMakerController>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await _confirmDialog(
      context,
      title: 'Apagar esta festa?',
      message:
          '${party.title.value} e tudo o que você montou nela serão apagados. '
          'Não dá para desfazer.',
      action: 'Apagar',
    );
    if (!confirmed) return;

    final deleted = await controller.deleteParty(party.id);
    _notify(
      messenger,
      deleted
          ? '${party.title.value} apagada.'
          : controller.error ?? 'Não foi possível apagar a festa.',
    );
  }

  /// No modo demonstração não há outra conta para fazer o papel do
  /// fornecedor: a própria pessoa responde, para ver o caminho inteiro.
  bool _canAnswerAsVendor(BuildContext context, Party party) {
    return party.status.acceptsVendorAnswers &&
        context.read<QuoteInboxRepository>() is DemoVendorAnswers;
  }

  Future<void> _answerAsVendor(BuildContext context) async {
    final controller = context.read<PartyMakerController>();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const QuoteInboxPage()),
    );
    // As respostas foram dadas sobre as mesmas festas: a tela busca de novo.
    await controller.load();
  }

  static void _notify(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    String dismiss = 'Cancelar',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dismiss),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// As ações que não cabem no rodapé: mexem na festa inteira.
class _PartyMenu extends StatelessWidget {
  const _PartyMenu({
    required this.party,
    required this.onHistory,
    required this.onEditEvent,
    required this.onCancel,
    required this.onDelete,
  });

  final Party party;
  final VoidCallback onHistory;
  final VoidCallback onEditEvent;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = party.status;
    // Uma festa que os fornecedores estão respondendo é cancelada, e não
    // apagada: assim o pedido não some para eles sem explicação.
    final canDelete = status.isEditable || status == PartyStatus.cancelled;

    return PopupMenuButton<VoidCallback>(
      tooltip: 'Mais opções da festa',
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: onHistory,
          child: const Text('Histórico da festa'),
        ),
        if (status.isEditable)
          PopupMenuItem(
            value: onEditEvent,
            child: const Text('Editar dados do evento'),
          ),
        if (status.isSubmitted)
          PopupMenuItem(value: onCancel, child: const Text('Cancelar festa')),
        if (canDelete)
          PopupMenuItem(value: onDelete, child: const Text('Apagar festa')),
      ],
    );
  }
}

/// Em que ponto a festa está e qual é o próximo passo.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.party, required this.onAnswerAsVendor});

  final Party party;

  /// Só existe no modo demonstração.
  final VoidCallback? onAnswerAsVendor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final status = party.status;
    final color = status.colorIn(colors);
    final round = party.quoteRound;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tint(color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(status.icon, color: color)),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    // Da segunda vez em diante é um reenvio: a pessoa já pediu
                    // antes e alterou a festa.
                    status.isSubmitted && round > 1
                        ? '${status.label} ($roundª rodada)'
                        : status.label,
                    style: text.cardTitle.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nextStepFor(party),
            style: text.body.copyWith(color: colors.textSecondary),
          ),
          if (onAnswerAsVendor != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAnswerAsVendor,
                child: const Text(
                  'Responder como fornecedor (demo)',
                  textAlign: TextAlign.end,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// O evento em três linhas: tipo, quando e para quantas pessoas.
class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.party, required this.onEdit});

  final Party party;

  /// `null` quando a festa não pode ser alterada agora.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = party.eventDate?.value;
    final guests = party.guestCount?.value;
    final eventType = party.eventType;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eventType != null)
                  EventTypeName(
                    slug: eventType,
                    builder: (_, name) =>
                        _SummaryLine(icon: Icons.celebration, text: name),
                  ),
                _SummaryLine(
                  icon: Icons.calendar_today_outlined,
                  text: date == null ? 'Data a definir' : formatEventDate(date),
                  isMissing: date == null,
                ),
                _SummaryLine(
                  icon: Icons.groups_outlined,
                  text: guests == null
                      ? 'Convidados a definir'
                      : guestsLabel(guests),
                  isMissing: guests == null,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar dados do evento',
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.text,
    this.isMissing = false,
  });

  final IconData icon;
  final String text;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 18, color: colors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.text.body.copyWith(
                color: isMissing ? colors.textSecondary : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O que falta para pedir o orçamento. Cada linha é a regra que barraria o
/// pedido, dita antes de a pessoa tentar.
class _Pendencies extends StatelessWidget {
  const _Pendencies({required this.blockers, required this.onFixEvent});

  final List<PartyDomainException> blockers;
  final VoidCallback onFixEvent;

  /// As pendências que se resolvem na tela dos dados do evento.
  static const Set<String> _aboutTheEvent = {
    'event_date_required',
    'event_date_in_past',
    'guest_count_required',
  };

  @override
  Widget build(BuildContext context) {
    if (blockers.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final text = context.text;
    final hasEventBlocker = blockers.any(
      (blocker) => _aboutTheEvent.contains(blocker.code),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        decoration: BoxDecoration(
          color: colors.tint(colors.warning),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Falta para pedir o orçamento',
                style: text.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.warning,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final blocker in blockers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• ${blocker.message}', style: text.body),
              ),
            if (hasEventBlocker)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onFixEvent,
                  child: const Text('Informar dados do evento'),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.category});

  final PartyItemCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(category.icon, size: 18, color: colors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(category.groupLabel, style: context.text.cardTitle),
            ),
          ),
        ],
      ),
    );
  }
}

/// A festa sem itens: diz o que falta e por onde começar.
class _NoItems extends StatelessWidget {
  const _NoItems({required this.canAdd});

  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final tabs = context.read<AppTabController>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.cake_outlined,
              size: 64,
              color: colors.textTertiary.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sua festa ainda não tem itens',
            style: text.sectionTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            canAdd
                ? 'Explore espaços, buffets, atrações e fornecedores e toque '
                      'no + de um anúncio para começar a montar.'
                : 'Esta festa não pode mais receber itens.',
            style: text.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (canAdd) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => tabs.goTo(AppTab.explore),
              child: const Text('Explorar anúncios'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => tabs.goTo(AppTab.home),
              child: const Text('Ver os mais procurados'),
            ),
          ],
        ],
      ),
    );
  }
}

/// O rodapé: quanto se estima, quanto os fornecedores informaram, e a ação
/// que cabe agora.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.party,
    required this.isBusy,
    required this.onRequestQuote,
    required this.onReopen,
    required this.onConfirm,
  });

  final Party party;
  final bool isBusy;
  final VoidCallback onRequestQuote;
  final VoidCallback onReopen;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = party.budget.items;
    final quoted = party.quotedTotal;
    final quotedCount = items.where((item) => item.quote.isQuoted).length;

    return Container(
      // A folga extra embaixo é do botão central da navegação, que sobe por
      // cima do fim desta aba: sem ela ele encobre a borda do botão do rodapé.
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + AppSpacing.navButtonOverlap,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        // No tema escuro a sombra não se vê: uma linha separa o rodapé.
        border: colors.isDark
            ? Border(top: BorderSide(color: colors.divider))
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalLine(
            label: 'Estimativa do evento',
            value: estimateSummary(party.estimate, itemCount: items.length),
          ),
          if (quoted != null)
            _TotalLine(
              label: quotedCount == items.length
                  ? 'Orçamento recebido'
                  : 'Orçamento recebido ($quotedCount de ${items.length})',
              value: formatBrl(quoted.cents),
              isQuote: true,
            ),
          ..._actions(),
        ],
      ),
    );
  }

  /// A ação que cabe em cada ponto do caminho. Um botão que não pode agir fica
  /// desabilitado, em vez de aceitar o toque e responder com um erro.
  List<Widget> _actions() {
    Widget primary(String label, VoidCallback? onPressed) {
      return FilledButton(
        onPressed: isBusy ? null : onPressed,
        child: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label, textAlign: TextAlign.center),
      );
    }

    const gap = SizedBox(height: 12);
    return switch (party.status) {
      PartyStatus.draft || PartyStatus.planning => [
        gap,
        primary(
          'Solicitar orçamento',
          party.quoteBlockers.isEmpty ? onRequestQuote : null,
        ),
      ],
      PartyStatus.quoted => [
        gap,
        primary('Aceitar orçamento', onConfirm),
        TextButton(
          onPressed: isBusy ? null : onReopen,
          child: const Text('Editar festa'),
        ),
      ],
      PartyStatus.locked ||
      PartyStatus.editRequested ||
      PartyStatus.confirmed => [gap, primary('Editar festa', onReopen)],
      PartyStatus.paid || PartyStatus.cancelled => const [],
    };
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.isQuote = false,
  });

  final String label;
  final String value;

  /// O valor informado pelos fornecedores, e não a conta do app.
  final bool isQuote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text.body.copyWith(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      // Com letras grandes o valor desce para a linha de baixo, em vez de
      // estourar a largura da tela.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: style.copyWith(
              color: isQuote ? colors.success : colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
