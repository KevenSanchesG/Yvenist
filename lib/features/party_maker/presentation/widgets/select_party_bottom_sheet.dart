import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/party_status_presentation.dart';

const int _partyTitleMaxLength = 80;

/// Abre a escolha da festa que vai receber [draft] e confirma com uma
/// mensagem quando o item entra.
Future<void> showAddToPartySheet(
  BuildContext context,
  PartyItemDraft draft,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final partyTitle = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SelectPartyBottomSheet(draft: draft),
  );

  if (partyTitle != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${draft.name} adicionado a $partyTitle.')),
      );
  }
}

/// Lista as festas que ainda aceitam itens e permite criar uma nova.
/// Fecha devolvendo o título da festa que recebeu o item.
class SelectPartyBottomSheet extends StatefulWidget {
  const SelectPartyBottomSheet({super.key, required this.draft});

  final PartyItemDraft draft;

  @override
  State<SelectPartyBottomSheet> createState() => _SelectPartyBottomSheetState();
}

class _SelectPartyBottomSheetState extends State<SelectPartyBottomSheet> {
  String? _errorMessage;

  Future<void> _addTo(Party party) async {
    final controller = context.read<PartyMakerController>();
    setState(() => _errorMessage = null);

    final added = await controller.addItemToParty(party.id, widget.draft);
    if (!mounted) return;

    if (added) {
      Navigator.pop(context, party.title.value);
    } else {
      // Fica aberta: a pessoa pode escolher outra festa.
      setState(() => _errorMessage = controller.error);
    }
  }

  Future<void> _addToNewParty() async {
    final controller = context.read<PartyMakerController>();
    setState(() => _errorMessage = null);

    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewPartyDialog(),
    );
    if (title == null || !mounted) return;

    final added = await controller.addItemToNewParty(title, widget.draft);
    if (!mounted) return;

    if (added) {
      Navigator.pop(context, title);
    } else {
      setState(() => _errorMessage = controller.error);
    }
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
              'Em qual festa você quer adicionar\n${widget.draft.name}?',
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
                        subtitle: Text(party.status.label),
                        trailing: const Icon(Icons.chevron_right),
                        enabled: !controller.isBusy,
                        onTap: () => _addTo(party),
                      ),
                  ],
                ),
              ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  style: context.text.body.copyWith(
                    color: context.colors.danger,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.isBusy ? null : _addToNewParty,
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
        maxLength: _partyTitleMaxLength,
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
