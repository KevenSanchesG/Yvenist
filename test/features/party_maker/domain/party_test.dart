import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../party_fixtures.dart';

const item1 = PartyItemId('item-1');
const item2 = PartyItemId('item-2');
const venue1 = PartyItemId('venue-1');

Matcher throwsCode(String code) =>
    throwsA(isA<PartyDomainException>().having((e) => e.code, 'code', code));

/// Uma festa com dois itens e o orçamento solicitado.
Party requestedParty() {
  return planningParty(
    items: [
      buildItem(),
      buildItem(id: 'item-2', externalId: 'listing-2', name: 'Bolo'),
    ],
  )..requestQuote();
}

VendorResponse quoteOf(int cents, {String? message}) =>
    VendorResponse.quote(Money.fromCents(cents), message: message);

/// Uma festa em um status que só o servidor (ou um dado antigo) produz.
Party partyIn(PartyStatus status, {List<PartyItem> items = const []}) {
  final source = planningParty(items: items);
  return Party(
    id: source.id,
    ownerId: source.ownerId,
    title: source.title,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    eventDate: source.eventDate,
    guestCount: source.guestCount,
    status: status,
    budget: source.budget,
    clock: fixedClock,
  );
}

void main() {
  group('Party: criação', () {
    test('nasce como rascunho, vazia e sem orçamento pedido', () {
      final party = buildParty();

      expect(party.status, PartyStatus.draft);
      expect(party.budget.items, isEmpty);
      expect(party.quoteSnapshot, isNull);
      expect(party.quoteRound, 0);
      expect(party.history, isEmpty);
      expect(party.eventType, isNull);
      expect(party.eventDate, isNull);
      expect(party.guestCount, isNull);
    });

    test('uma cópia é independente da original', () {
      final party = planningParty();

      final copy = party.clone()..removeItem(item1);

      expect(copy.budget.items, isEmpty);
      expect(party.budget.items, hasLength(1));
      expect(copy.id, party.id);
    });
  });

  group('Party: o evento', () {
    test('rascunho pode iniciar o planejamento, e só ele', () {
      final party = buildParty()..startPlanning();

      expect(party.status, PartyStatus.planning);
      expect(party.startPlanning, throwsA(isA<InvalidPartyTransition>()));
    });

    test('guarda o nome, o tipo, a data e os convidados', () {
      final party = buildParty()..startPlanning();

      party.updateEventDetails(
        buildDetails(
          title: 'Natal em família',
          eventType: 'wedding',
          eventDate: kEventDay,
          guests: 40,
        ),
      );

      expect(party.title.value, 'Natal em família');
      expect(party.eventType, 'wedding');
      expect(party.eventDate, EventDate(kEventDay));
      expect(party.guestCount, GuestCount(40));
    });

    test('a data informada precisa ser no futuro', () {
      final party = buildParty()..startPlanning();

      expect(
        () => party.updateEventDetails(
          buildDetails(eventDate: kFixedNow.subtract(const Duration(days: 1))),
        ),
        throwsA(isA<EventDateInPast>()),
      );
      // "Agora" também não é futuro.
      expect(
        () => party.updateEventDetails(buildDetails(eventDate: kFixedNow)),
        throwsA(isA<EventDateInPast>()),
      );
    });

    test('uma festa cuja data já passou ainda pode ser renomeada', () {
      // Só a data que está sendo informada agora é conferida.
      final clock = TestClock();
      final party = planningParty(clock: clock.call);
      clock.now = kEventDay.add(const Duration(days: 30));

      party.updateEventDetails(
        buildDetails(
          title: 'Festa que passou',
          eventDate: kEventDay,
          guests: 80,
        ),
      );

      expect(party.title.value, 'Festa que passou');
    });

    test('os convidados não passam da capacidade do salão', () {
      final party = planningParty(items: [buildVenue(capacity: 120)]);

      expect(
        () => party.updateEventDetails(
          buildDetails(eventDate: kEventDay, guests: 121),
        ),
        throwsA(
          isA<GuestCountExceedsCapacity>().having(
            (e) => e.message,
            'message',
            contains('120'),
          ),
        ),
      );
      expect(party.guestCount, GuestCount(80));
    });

    test('toda mudança atualiza a data de alteração', () {
      final clock = TestClock();
      final party = buildParty(clock: clock.call);
      clock.advance(const Duration(minutes: 5));

      party.startPlanning();

      expect(party.updatedAt, kFixedNow.add(const Duration(minutes: 5)));
      expect(party.createdAt, kFixedNow);
    });
  });

  group('Party: itens', () {
    test('aceita itens em rascunho e em planejamento', () {
      final draft = buildParty()..addItems([buildItem()]);
      final planning = buildParty()
        ..startPlanning()
        ..addItems([buildItem()]);

      expect(draft.budget.items, hasLength(1));
      expect(planning.budget.items, hasLength(1));
    });

    test('pode ficar sem itens: tirar o último não apaga a festa', () {
      final party = planningParty();

      final removal = party.removeItem(item1);

      expect(removal.item.id, item1);
      expect(party.budget.isEmpty, isTrue);
      expect(party.status, PartyStatus.planning);
    });

    test('o que a categoria pede é conferido na entrada', () {
      final party = planningParty(items: const []);

      expect(
        () =>
            party.addItems([buildItem(category: PartyItemCategory.decoration)]),
        throwsA(
          isA<InvalidItemConfiguration>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            {'theme': 'Campo obrigatório.'},
          ),
        ),
      );
      expect(party.budget.isEmpty, isTrue);
    });

    test('um item que não tem quantidade entra uma vez só', () {
      final party = planningParty(items: const []);

      expect(
        () => party.addItems([
          buildItem(
            category: PartyItemCategory.dj,
            configuration: kFourHours,
            quantity: 2,
          ),
        ]),
        throwsA(isA<InvalidQuantity>()),
      );
    });

    test('o salão só entra com a data e os convidados informados', () {
      final noDate = planningParty(items: const [], withEventDate: false);
      final noGuests = planningParty(items: const [], guests: null);

      expect(
        () => noDate.addItems([buildVenue()]),
        throwsA(isA<EventDetailsRequired>()),
      );
      expect(
        () => noGuests.addItems([buildVenue()]),
        throwsA(isA<EventDetailsRequired>()),
      );
    });

    test('o salão não entra se não comporta os convidados', () {
      final party = planningParty(items: const [], guests: 200);

      expect(
        () => party.addItems([buildVenue(capacity: 120)]),
        throwsA(isA<GuestCountExceedsCapacity>()),
      );
    });

    test('um item cobrado por pessoa pede o número de convidados', () {
      final party = planningParty(items: const [], guests: null);

      expect(
        () => party.addItems([
          buildItem(model: PricingModel.perPerson, priceCents: 5500),
        ]),
        throwsA(isA<GuestCountRequired>()),
      );
    });

    test('um anúncio entra com os serviços dele, ou nada entra', () {
      final party = planningParty(items: const []);

      expect(
        () => party.addItems([
          buildVenue(),
          // Cobrado por hora e sem a duração: não passa.
          buildOwnService(model: PricingModel.perHour, priceCents: 18000),
        ]),
        throwsA(isA<InvalidItemConfiguration>()),
      );
      expect(party.budget.isEmpty, isTrue);
    });

    test('mantém a regra de salão único', () {
      final party = planningParty(items: [buildVenue()]);

      expect(
        () => party.addItems([buildVenue(id: 'venue-2', externalId: 'outro')]),
        throwsA(isA<VenueAlreadySelected>()),
      );
    });

    test('alterar um item troca só o que a pessoa informa', () {
      final party = planningParty();

      party.updateItem(
        item1,
        quantity: Quantity(3),
        configuration: {'variation': ' Azul ', 'notes': ''},
      );

      final item = party.budget.findById(item1)!;
      expect(item.quantity, Quantity(3));
      expect(
        item.configuration,
        ItemConfiguration(const {'variation': 'Azul'}),
      );
      // O que foi copiado do catálogo continua como entrou.
      expect(item.nameSnapshot, 'Kit de copos');
      expect(item.pricing.amount, Money.fromCents(80000));
    });

    test('alterar um item confere a configuração de novo', () {
      final party = planningParty(items: [buildVenue()]);

      expect(
        () => party.updateItem(
          venue1,
          quantity: Quantity(1),
          configuration: const {'duration_hours': 30},
        ),
        throwsA(isA<InvalidItemConfiguration>()),
      );
      expect(
        () => party.updateItem(
          venue1,
          quantity: Quantity(2),
          configuration: kFourHours,
        ),
        throwsA(isA<InvalidQuantity>()),
      );
    });

    test('alterar um item que não está na festa falha', () {
      expect(
        () => planningParty().updateItem(
          const PartyItemId('nao-existe'),
          quantity: Quantity(1),
          configuration: const {},
        ),
        throwsA(isA<PartyItemNotFound>()),
      );
    });

    test('um serviço obrigatório não sai sozinho', () {
      final party = planningParty(
        items: [
          buildVenue(),
          buildOwnService(
            name: 'Taxa de limpeza',
            category: PartyItemCategory.other,
            model: PricingModel.fixed,
            priceCents: 15000,
            isRequired: true,
          ),
        ],
      );

      expect(
        () => party.removeItem(const PartyItemId('service-1')),
        throwsA(
          isA<RequiredItemCannotLeaveAlone>()
              .having((e) => e.code, 'code', 'required_item_missing')
              .having(
                (e) => e.message,
                'message',
                allOf(contains('Taxa de limpeza'), contains('Salão Glamour')),
              ),
        ),
      );
      // Sai junto com o salão.
      final removal = party.removeItem(venue1);
      expect(removal.removedWith.single.nameSnapshot, 'Taxa de limpeza');
      expect(party.budget.isEmpty, isTrue);
    });

    test('remover um item solta o parceiro que ele tinha recomendado', () {
      final party = planningParty(
        items: [
          buildVenue(),
          buildItem(relation: const ItemRelation.recommendedBy(venue1)),
        ],
      );

      final removal = party.removeItem(venue1);

      expect(removal.released.single.id, item1);
      expect(
        party.budget.items.single.relation,
        const ItemRelation.independent(),
      );
    });
  });

  group('Party: o que falta para pedir o orçamento', () {
    test('festa pronta não tem pendências', () {
      expect(planningParty().quoteBlockers, isEmpty);
    });

    test('lista todas as pendências de uma vez', () {
      final party = buildParty()..startPlanning();

      expect(party.quoteBlockers.map((blocker) => blocker.code), [
        'cannot_lock_without_items',
        'event_date_required',
        'guest_count_required',
      ]);
    });

    test('a data que já passou é uma pendência', () {
      final clock = TestClock();
      final party = planningParty(clock: clock.call);
      clock.now = kEventDay.add(const Duration(days: 1));

      expect(party.quoteBlockers.single, isA<EventDateInPast>());
    });

    test('um item cujo anúncio saiu do catálogo é uma pendência', () {
      final party = planningParty(
        items: [
          buildItem(
            ref: const ExternalRef.unavailable('item-1'),
            name: 'DJ que saiu',
          ),
        ],
      );

      final blocker = party.quoteBlockers.single;
      expect(blocker, isA<ItemNoLongerAvailable>());
      expect(blocker.message, contains('DJ que saiu'));
    });
  });

  group('Party: solicitar o orçamento', () {
    test('congela a festa e manda cada item para o fornecedor', () {
      final party = planningParty(
        items: [
          buildItem(),
          buildItem(
            id: 'item-2',
            externalId: 'listing-2',
            model: PricingModel.onRequest,
            priceCents: null,
          ),
        ],
      )..requestQuote();

      expect(party.status, PartyStatus.locked);
      expect(party.quoteRound, 1);
      expect(
        party.budget.items.map((item) => item.quote.status),
        everyElement(QuoteStatus.pending),
      );
      // O retrato do que a pessoa viu ao pedir: a estimativa e o que ficou
      // fora dela.
      expect(party.quoteSnapshot!.requestedAt, kFixedNow);
      expect(party.quoteSnapshot!.estimatedTotal, Money.fromCents(80000));
      expect(party.quoteSnapshot!.unpricedItems, 1);

      final entry = party.history.single;
      expect(entry.kind, PartyHistoryKind.quoteRequested);
      expect(entry.actor, PartyHistoryActor.client);
      expect(entry.round, 1);
      expect(entry.amount, Money.fromCents(80000));
    });

    test('exige estar em planejamento', () {
      final draft = buildParty()
        ..updateEventDetails(buildDetails(eventDate: kEventDay, guests: 80))
        ..addItems([buildItem()]);

      expect(draft.requestQuote, throwsA(isA<InvalidPartyTransition>()));
      expect(
        requestedParty().requestQuote,
        throwsCode('invalid_party_transition'),
      );
    });

    test('barra pela primeira pendência', () {
      expect(
        planningParty(items: const []).requestQuote,
        throwsA(isA<CannotLockWithoutItems>()),
      );
      expect(
        planningParty(withEventDate: false).requestQuote,
        throwsA(isA<EventDateRequired>()),
      );
      expect(
        planningParty(guests: null).requestQuote,
        throwsA(isA<GuestCountRequired>()),
      );
    });

    test('festa com o orçamento solicitado não aceita mudanças', () {
      final party = requestedParty();

      expect(
        () => party.addItems([buildItem(id: 'x', externalId: 'x')]),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
      expect(
        () => party.removeItem(item1),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
      expect(
        () => party.updateItem(
          item1,
          quantity: Quantity(2),
          configuration: const {},
        ),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
      expect(
        () => party.updateEventDetails(buildDetails(title: 'Outro nome')),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
    });
  });

  group('Party: a resposta do fornecedor', () {
    test('o valor informado fica no item, separado da estimativa', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000, message: ' Com frete '));

      final item = party.budget.findById(item1)!;
      expect(item.quote.status, QuoteStatus.quoted);
      expect(item.quote.amount, Money.fromCents(90000));
      expect(item.quote.message, 'Com frete');
      expect(item.quote.respondedAt, kFixedNow);
      // A estimativa continua sendo a conta com o preço do anúncio.
      expect(item.estimate(guests: 80), Money.fromCents(80000));
      expect(party.quotedTotal, Money.fromCents(90000));
      // Ainda falta um fornecedor.
      expect(party.status, PartyStatus.locked);
    });

    test('quando todos respondem com o valor, o orçamento foi recebido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, quoteOf(10000));

      expect(party.status, PartyStatus.quoted);
      expect(party.quotedTotal, Money.fromCents(100000));
      expect(party.history.map((entry) => entry.kind), [
        PartyHistoryKind.quoteRequested,
        PartyHistoryKind.vendorQuoted,
        PartyHistoryKind.vendorQuoted,
      ]);
      final last = party.history.last;
      expect(last.actor, PartyHistoryActor.vendor);
      expect(last.itemId, item2);
      expect(last.itemName, 'Bolo');
      expect(last.amount, Money.fromCents(10000));
    });

    test('um pedido de alteração devolve a festa para a pessoa', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(
          item2,
          const VendorResponse.requestChanges('Só atendo até 60 pessoas.'),
        );

      expect(party.status, PartyStatus.editRequested);
      expect(party.itemsNeedingAttention.single.id, item2);
      final item = party.budget.findById(item2)!;
      expect(item.quote.message, 'Só atendo até 60 pessoas.');
      expect(item.quote.amount, isNull);
      expect(party.history.last.kind, PartyHistoryKind.vendorRequestedChanges);
    });

    test('uma recusa também devolve a festa para a pessoa', () {
      final party = requestedParty()
        ..registerVendorResponse(
          item1,
          const VendorResponse.decline('Sem agenda neste dia.'),
        );

      expect(party.status, PartyStatus.editRequested);
      expect(party.history.last.kind, PartyHistoryKind.vendorDeclined);
    });

    test('pedir alteração ou recusar exige o motivo', () {
      final party = requestedParty();

      expect(
        () => party.registerVendorResponse(
          item1,
          const VendorResponse.requestChanges('  ok '),
        ),
        throwsA(isA<InvalidQuoteResponse>()),
      );
      expect(
        () => party.registerVendorResponse(
          item1,
          const VendorResponse.decline(''),
        ),
        throwsA(isA<InvalidQuoteResponse>()),
      );
      expect(party.budget.findById(item1)!.quote.status, QuoteStatus.pending);
    });

    test('o valor tem limites, e zero é um valor', () {
      final party = requestedParty();

      expect(
        () => party.registerVendorResponse(item1, quoteOf(-1)),
        throwsA(isA<InvalidQuoteResponse>()),
      );
      expect(
        () => party.registerVendorResponse(
          item1,
          quoteOf(VendorResponse.maxAmountCents + 1),
        ),
        throwsA(isA<InvalidQuoteResponse>()),
      );

      party.registerVendorResponse(item1, quoteOf(0));
      expect(party.budget.findById(item1)!.quote.amount, Money.zero());
    });

    test('a mensagem tem tamanho máximo', () {
      expect(
        () => requestedParty().registerVendorResponse(
          item1,
          quoteOf(100, message: 'x' * 501),
        ),
        throwsA(isA<InvalidQuoteResponse>()),
      );
    });

    test('o fornecedor pode corrigir a resposta enquanto a pessoa não '
        'aceita', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, quoteOf(10000))
        ..registerVendorResponse(item2, quoteOf(12000));

      expect(party.status, PartyStatus.quoted);
      expect(party.quotedTotal, Money.fromCents(102000));
    });

    test('só responde a um pedido que está aberto', () {
      final planning = planningParty();
      final confirmed = requestedParty()
        ..registerVendorResponse(item1, quoteOf(1))
        ..registerVendorResponse(item2, quoteOf(1))
        ..confirmQuote();
      final cancelled = requestedParty()..cancel();

      for (final party in [planning, confirmed, cancelled]) {
        expect(
          () => party.registerVendorResponse(item1, quoteOf(100)),
          throwsA(isA<QuoteRequestClosed>()),
          reason: party.status.name,
        );
      }
      expect(
        () => requestedParty().registerVendorResponse(
          const PartyItemId('nao-existe'),
          quoteOf(100),
        ),
        throwsA(isA<QuoteRequestClosed>()),
      );
    });
  });

  group('Party: voltar a editar', () {
    test('volta para o planejamento e guarda o que já foi respondido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..reopenForEditing();

      expect(party.status, PartyStatus.planning);
      expect(party.quoteSnapshot, isNull);
      // Quem respondeu continua à vista; o pedido de quem não respondeu foi
      // retirado.
      expect(party.budget.findById(item1)!.quote.isQuoted, isTrue);
      expect(party.budget.findById(item2)!.quote.status, QuoteStatus.none);
      expect(party.history.last.kind, PartyHistoryKind.reopened);
    });

    test('vale em qualquer ponto depois do pedido, até do aceite', () {
      final quoted = requestedParty()
        ..registerVendorResponse(item1, quoteOf(1))
        ..registerVendorResponse(item2, quoteOf(1));
      final confirmed = quoted.clone()..confirmQuote();
      final editRequested = requestedParty()
        ..registerVendorResponse(
          item1,
          const VendorResponse.decline('Não dá.'),
        );

      for (final party in [
        requestedParty(),
        quoted,
        confirmed,
        editRequested,
      ]) {
        party.reopenForEditing();
        expect(party.status, PartyStatus.planning);
      }
    });

    test('só reabre uma festa com o orçamento solicitado', () {
      expect(
        planningParty().reopenForEditing,
        throwsA(isA<InvalidPartyTransition>()),
      );
    });

    test('alterar um item descarta o valor que o fornecedor tinha dado', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, quoteOf(10000))
        ..reopenForEditing()
        ..updateItem(item1, quantity: Quantity(2), configuration: const {});

      // O valor era para a configuração anterior.
      expect(party.budget.findById(item1)!.quote.status, QuoteStatus.none);
      expect(party.budget.findById(item2)!.quote.isQuoted, isTrue);
    });

    test('salvar um item sem mudar nada mantém o valor recebido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..reopenForEditing()
        ..updateItem(item1, quantity: Quantity(1), configuration: const {});

      expect(party.budget.findById(item1)!.quote.isQuoted, isTrue);
    });

    test('mudar o evento descarta todos os valores; mudar só o nome, não', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, quoteOf(10000))
        ..reopenForEditing();

      party.updateEventDetails(
        buildDetails(title: 'Outro nome', eventDate: kEventDay, guests: 80),
      );
      expect(party.quotedTotal, Money.fromCents(100000));

      // O valor de cada fornecedor valia para o evento de antes.
      party.updateEventDetails(
        buildDetails(title: 'Outro nome', eventDate: kEventDay, guests: 90),
      );
      expect(party.quotedTotal, isNull);
    });

    test('pedir de novo é outra rodada, e só o que mudou volta a ser '
        'pedido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(
          item2,
          const VendorResponse.requestChanges('Diminua a quantidade.'),
        )
        ..reopenForEditing()
        ..updateItem(item2, quantity: Quantity(2), configuration: const {})
        ..requestQuote();

      expect(party.quoteRound, 2);
      expect(party.status, PartyStatus.locked);
      // Quem já deu o valor, e nada mudou para ele, não responde de novo.
      expect(party.budget.findById(item1)!.quote.isQuoted, isTrue);
      expect(party.budget.findById(item2)!.quote.status, QuoteStatus.pending);
      expect(party.history.last.round, 2);
    });

    test('se nada mudou e todos já tinham respondido, o orçamento volta '
        'como recebido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, quoteOf(10000))
        ..reopenForEditing()
        ..requestQuote();

      expect(party.status, PartyStatus.quoted);
      expect(party.quoteRound, 2);
    });

    test('tirado o item recusado, o que sobrou já estava respondido', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, const VendorResponse.decline('Não dá.'))
        ..reopenForEditing()
        ..removeItem(item2)
        ..requestQuote();

      expect(party.status, PartyStatus.quoted);
    });

    test('um item recusado que continua na festa é pedido de novo', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000))
        ..registerVendorResponse(item2, const VendorResponse.decline('Não dá.'))
        ..reopenForEditing()
        ..requestQuote();

      expect(party.status, PartyStatus.locked);
      expect(party.budget.findById(item2)!.quote.status, QuoteStatus.pending);
    });
  });

  group('Party: aceitar o orçamento', () {
    test('só depois que todos os fornecedores responderam', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(90000));

      expect(party.confirmQuote, throwsA(isA<InvalidPartyTransition>()));

      party
        ..registerVendorResponse(item2, quoteOf(10000))
        ..confirmQuote();

      expect(party.status, PartyStatus.confirmed);
      expect(party.history.last.kind, PartyHistoryKind.confirmed);
      expect(party.history.last.amount, Money.fromCents(100000));
    });

    test('festa aceita continua congelada', () {
      final party = requestedParty()
        ..registerVendorResponse(item1, quoteOf(1))
        ..registerVendorResponse(item2, quoteOf(1))
        ..confirmQuote();

      expect(
        () => party.removeItem(item1),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
    });
  });

  group('Party: cancelar e apagar', () {
    test('cancela em planejamento e com o orçamento solicitado', () {
      final planning = planningParty()..cancel();
      final requested = requestedParty()..cancel();

      expect(planning.status, PartyStatus.cancelled);
      expect(requested.status, PartyStatus.cancelled);
      expect(requested.quoteSnapshot, isNull);
      expect(requested.history.last.kind, PartyHistoryKind.cancelled);
    });

    test('não cancela duas vezes nem altera uma festa cancelada', () {
      final party = planningParty()..cancel();

      expect(party.cancel, throwsA(isA<InvalidPartyTransition>()));
      expect(
        () => party.updateEventDetails(buildDetails(title: 'Outro nome')),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        () => party.addItems([buildItem(id: 'x', externalId: 'x')]),
        throwsA(isA<InvalidPartyTransition>()),
      );
    });

    test('festa paga não é cancelada, alterada nem apagada', () {
      final party = partyIn(PartyStatus.paid, items: [buildItem()]);

      expect(party.cancel, throwsA(isA<InvalidPartyTransition>()));
      expect(
        () => party.removeItem(item1),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        party.ensureCanBeDeleted,
        throwsA(isA<PaidPartyCannotBeDeleted>()),
      );
    });

    test('com o pedido nas mãos dos fornecedores, cancela antes de apagar', () {
      final quoted = requestedParty()
        ..registerVendorResponse(item1, quoteOf(1))
        ..registerVendorResponse(item2, quoteOf(1));

      for (final party in [requestedParty(), quoted]) {
        expect(party.ensureCanBeDeleted, throwsA(isA<PartyHasOpenQuote>()));
      }

      expect(planningParty().ensureCanBeDeleted, returnsNormally);
      expect((requestedParty()..cancel()).ensureCanBeDeleted, returnsNormally);
    });
  });

  group('Party: identidade', () {
    test('o título é um valor validado', () {
      expect(buildParty().title, PartyTitle('Aniversário da Ana'));
      expect(buildParty().id, const PartyId('party-1'));
    });
  });
}
