import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/party_maker/presentation/models/party_target.dart';
import 'package:yvenist/features/party_maker/presentation/pages/item_configuration_page.dart';
import 'package:yvenist/features/party_maker/presentation/widgets/select_party_bottom_sheet.dart';

/// O caminho de um anúncio até dentro de uma festa.
///
/// É a porta de entrada do Party Maker para o resto do app: a vitrine, a
/// busca e os favoritos só chamam [startAddToPartyFlow] com o id e o nome do
/// anúncio. Escolher a festa, configurar o item, validar e gravar acontecem
/// aqui dentro.

/// Pergunta em qual festa o anúncio entra, abre a configuração dele e, no
/// fim, confirma com um aviso.
Future<void> startAddToPartyFlow(
  BuildContext context, {
  required String listingId,
  required String itemName,
}) async {
  final target = await showSelectPartySheet(context, itemName: itemName);
  if (target == null || !context.mounted) return;

  await configureAndAddToParty(
    context,
    listingId: listingId,
    itemName: itemName,
    target: target,
  );
}

/// Abre a configuração do anúncio para a festa [target] já escolhida.
///
/// Se o anúncio já está naquela festa, abre o item que está lá para a pessoa
/// alterar, em vez de pôr o mesmo anúncio duas vezes.
Future<void> configureAndAddToParty(
  BuildContext context, {
  required String listingId,
  required String itemName,
  required PartyTarget target,
  PartyItemId? recommendedBy,
}) async {
  final controller = context.read<PartyMakerController>();
  final tabs = context.read<AppTabController>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final party = target is ExistingPartyTarget
      ? controller.partyById(target.partyId)
      : null;
  final existing = party?.budget.findByExternalRef(
    ExternalRef.listing(listingId),
  );

  if (party != null && existing != null) {
    final saved = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemConfigurationPage.edit(
          partyId: party.id,
          itemId: existing.id,
          itemName: itemName,
          notice:
              '$itemName já está em ${party.title.value}. Altere o que '
              'precisar: o mesmo item não entra duas vezes.',
        ),
      ),
    );
    if (saved == true) {
      _confirm(
        messenger,
        '$itemName atualizado em ${party.title.value}.',
        onOpen: () => _open(controller, tabs, navigator, party.id),
      );
    }
    return;
  }

  // A festa em que o item entrou: a escolhida, ou a que nasceu com ele.
  final saved = await navigator.push<Party>(
    MaterialPageRoute(
      builder: (_) => ItemConfigurationPage.add(
        listingId: listingId,
        itemName: itemName,
        target: target,
        recommendedBy: recommendedBy,
      ),
    ),
  );
  if (saved == null) return;

  _confirm(
    messenger,
    '$itemName adicionado a ${saved.title.value}.',
    onOpen: () => _open(controller, tabs, navigator, saved.id),
  );
}

/// Leva a pessoa até a festa [partyId], de onde quer que ela esteja.
void _open(
  PartyMakerController controller,
  AppTabController tabs,
  NavigatorState navigator,
  PartyId partyId,
) {
  navigator.popUntil((route) => route.isFirst);
  controller.setActiveParty(partyId);
  tabs.goTo(AppTab.partyMaker);
}

void _confirm(
  ScaffoldMessengerState messenger,
  String message, {
  required VoidCallback onOpen,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Ver festa', onPressed: onOpen),
      ),
    );
}
