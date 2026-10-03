import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_target.dart';
import 'package:yvenist/features/party_maker/presentation/party_presentation.dart';

/// Pergunta em qual festa [itemName] vai entrar: uma das que estão em
/// planejamento, ou uma nova. Devolve a escolha, ou `null` se a pessoa
/// desistiu.
///
/// Só escolhe: o item entra depois de configurado (`ItemConfigurationPage`).
Future<PartyTarget?> showSelectPartySheet(
  BuildContext context, {
  required String itemName,
}) {
  return showModalBottomSheet<PartyTarget>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SelectPartyBottomSheet(itemName: itemName),
  );
}

/// Lista as festas que ainda aceitam itens e permite criar uma nova.
class SelectPartyBottomSheet extends StatelessWidget {
  const SelectPartyBottomSheet({super.key, required this.itemName});

  final String itemName;

  Future<void> _createNew(BuildContext context) async {
    final navigator = Navigator.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPartyDialog(),
    );
    if (title != null) navigator.pop(NewPartyTarget(title));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PartyMakerController>();
    final parties = controller.editableParties;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Em qual festa você quer adicionar\n$itemName?',
              style: context.text.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (parties.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Você ainda não tem festas em planejamento.',
                  style: context.text.body.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final party in parties)
                      ListTile(
                        title: Text(party.title.value),
                        subtitle: Text(
                          '${party.status.label} · '
                          '${itemsLabel(party.budget.items.length)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(
                          context,
                          ExistingPartyTarget(party.id),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _createNew(context),
              icon: const Icon(Icons.add),
              label: const Text('Criar nova festa'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pede o nome da nova festa. Fecha devolvendo o nome digitado.
class _NewPartyDialog extends StatefulWidget {
  const _NewPartyDialog();

  @override
  State<_NewPartyDialog> createState() => _NewPartyDialogState();
}

class _NewPartyDialogState extends State<_NewPartyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final title = _controller.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nome da nova festa'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PartyTitle.maxLength,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nome da festa',
          hintText: 'Ex.: 15 anos da Maria',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _confirm,
          child: const Text('Criar festa'),
        ),
      ],
    );
  }
}
