import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/core/widgets/form_widgets.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/pages/event_details_page.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// As festas da pessoa: de onde ela abre uma para montar ou acompanhar, e de
/// onde começa uma nova.
class MyPartiesPage extends StatelessWidget {
  const MyPartiesPage({super.key});

  void _createParty(BuildContext context) {
    // Criada, a festa já abre na aba: o controller a deixa como a festa ativa.
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const EventDetailsPage.create()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final tabs = context.read<AppTabController>();
    final parties = controller.parties;
    final loadError = controller.loadError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Festas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: 'Voltar ao início',
          onPressed: () => tabs.goTo(AppTab.home),
        ),
      ),
      body: parties.isEmpty
          ? EmptyStateView(
              icon: Icons.cake_outlined,
              title: 'Você ainda não tem festas',
              message:
                  'Crie uma festa e reúna nela o salão, o buffet, as atrações '
                  'e os serviços. Você vê a estimativa na hora e pede o '
                  'orçamento de tudo de uma vez.',
              actionLabel: 'Criar festa',
              onAction: () => _createParty(context),
              footer: TextButton(
                onPressed: () => tabs.goTo(AppTab.explore),
                child: const Text('Explorar anúncios'),
              ),
            )
          : RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (loadError != null) ...[
                    // A lista que já estava na tela continua nela: a pessoa
                    // só fica sabendo que pode estar desatualizada.
                    FormErrorBanner(
                      message: 'Não foi possível atualizar. $loadError',
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => _createParty(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova festa'),
                  ),
                  const SizedBox(height: 16),
                  for (final party in parties) ...[
                    _PartyCard(
                      party: party,
                      onTap: () => controller.setActiveParty(party.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Uma festa na lista: o nome, em que pé está, quando é e quanto soma.
class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.party, required this.onTap});

  final Party party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final status = party.status;
    final statusColor = status.colorIn(colors);
    final items = party.budget.items;
    final date = party.eventDate?.value;
    final guests = party.guestCount?.value;
    final quoted = party.quotedTotal;
    final event = [
      if (date != null) formatEventDate(date),
      if (guests != null) guestsLabel(guests),
    ].join(' · ');

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(party.title.value, style: text.cardTitle),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            status.icon,
                            size: 16,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            status.label,
                            style: text.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.isNotEmpty) Text(event, style: text.caption),
                    Text(
                      items.isEmpty
                          ? 'Sem itens'
                          : '${itemsLabel(items.length)} · Estimativa: '
                                '${estimateSummary(party.estimate, itemCount: items.length)}',
                      style: text.caption,
                    ),
                    if (quoted != null)
                      Text(
                        'Orçamento recebido: ${formatBrl(quoted.cents)}',
                        style: text.caption.copyWith(
                          color: colors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
