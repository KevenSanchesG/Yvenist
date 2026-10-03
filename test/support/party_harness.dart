import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/client/shared/listing_party_item_catalog.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import 'app_harness.dart';

/// Auxiliares dos testes de tela do Party Maker.

/// Rola a lista da tela até [finder] aparecer.
///
/// A tela da festa monta os itens conforme eles entram na tela: o que está
/// mais abaixo ainda não existe para o teste, como não existe para quem olha.
///
/// [upwards] procura de volta, em direção ao topo da lista.
Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  bool upwards = false,
}) async {
  await tester.scrollUntilVisible(
    finder,
    upwards ? -120 : 120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Rola até [finder] aparecer, toca e espera a tela estabilizar.
Future<void> revealAndTap(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tapAndSettle(tester, finder);
}

/// Na festa aberta: abre o menu "Mais opções" e escolhe [option].
Future<void> choosePartyOption(WidgetTester tester, String option) async {
  await tapAndSettle(tester, find.byTooltip('Mais opções da festa'));
  await tapAndSettle(tester, find.text(option));
}

/// Toca no "+" de [listing] e cria a festa [title] na escolha: a tela fica na
/// configuração do item. Nada entra na festa antes de confirmar.
Future<void> startAddingToNewParty(
  WidgetTester tester,
  String listing, {
  required String title,
}) async {
  await tapAndSettle(tester, find.byTooltip('Adicionar $listing a uma festa'));
  await tapAndSettle(tester, find.text('Criar nova festa'));
  await tester.enterText(find.byType(TextField), title);
  await tester.pump();
  await tapAndSettle(tester, filledButton('Criar festa'));
}

/// Marca a data e o horário que os seletores sugerem (daqui a 30 dias, às
/// 19h) e informa os convidados.
///
/// [optional] diz se os campos estão na tela do evento, onde nada é
/// obrigatório, ou na configuração de um salão, que não entra sem eles.
Future<void> fillEvent(
  WidgetTester tester, {
  String guests = '80',
  bool optional = false,
}) async {
  final suffix = optional ? ' (opcional)' : '';

  await scrollToAndTap(
    tester,
    find.widgetWithText(TextFormField, 'Data$suffix'),
  );
  await tapAndSettle(tester, find.text('OK'));
  await scrollToAndTap(
    tester,
    find.widgetWithText(TextFormField, 'Horário de início$suffix'),
  );
  await tapAndSettle(tester, find.text('OK'));
  await enterField(tester, 'Número de convidados$suffix', guests);
}

/// Na configuração de um salão: o evento e a duração, que é o que ele pede.
Future<void> fillVenue(
  WidgetTester tester, {
  String guests = '80',
  String hours = '4',
}) async {
  await fillEvent(tester, guests: guests);
  await enterField(tester, 'Duração (horas)', hours);
}

/// O caminho inteiro, pela tela: do "+" do salão [listing] até ele estar na
/// festa nova [title].
Future<void> addVenueToNewParty(
  WidgetTester tester,
  String listing, {
  required String title,
}) async {
  await startAddingToNewParty(tester, listing, title: title);
  await fillVenue(tester);
  await tapAndSettle(tester, filledButton('Adicionar à festa'));
}

/// Monta uma festa pelo controller, sem passar pelas telas: o ponto de
/// partida dos testes que não são sobre a montagem.
///
/// A festa nasce com data, 80 convidados, o salão [venueId] por 4 horas e a
/// taxa obrigatória dele. [withBuffet] põe junto o buffet do salão (por
/// pessoa) e [withAttraction], a "Atração Festiva 8" por 4 horas. Ela fica
/// como a festa aberta na aba.
Future<Party> seedParty(
  WidgetTester tester,
  TestApp app, {
  required String title,
  String venueId = 'demo-venue-8',
  bool withAttraction = true,
  bool withBuffet = false,
  int guests = 80,
  DateTime? eventDate,
}) async {
  final catalog = ListingPartyItemCatalog(app.dependencies.catalog);
  final controller = app.state.parties;
  const fourHours = {'duration_hours': 4};

  final venue = await catalog.draftFor(venueId);
  final saved = await controller.addItemToNewParty(
    EventDetails(
      title: PartyTitle(title),
      eventDate: EventDate(
        eventDate ?? DateTime.now().add(const Duration(days: 60)),
      ),
      guestCount: GuestCount(guests),
    ),
    ConfiguredItem(
      draft: venue,
      configuration: fourHours,
      ownServices: [
        for (final service in venue.ownServices)
          if (service.isRequired ||
              (withBuffet && service.category == PartyItemCategory.buffet))
            ConfiguredItem(draft: service),
      ],
    ),
  );
  if (saved == null) fail('A festa não foi criada: ${controller.error}');

  if (withAttraction) {
    final added = await controller.addItem(
      saved.id,
      ConfiguredItem(
        draft: await catalog.draftFor('demo-attraction-8'),
        configuration: fourHours,
      ),
    );
    if (added == null) fail('A atração não entrou: ${controller.error}');
  }

  await tester.pumpAndSettle();
  return controller.partyById(saved.id)!;
}

/// Responde a todos os pedidos de orçamento em aberto com o mesmo valor, como
/// os fornecedores fariam. A tela só vê as respostas depois de atualizar.
Future<void> answerAll(TestApp app, {required int cents}) async {
  final inbox = app.dependencies.quoteInbox;
  for (final request in await inbox.list()) {
    await inbox.respond(
      request.itemId,
      VendorResponse.quote(Money.fromCents(cents)),
    );
  }
}
