import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_assembly.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/add_item_to_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/cancel_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/confirm_quote_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/create_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/delete_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/remove_item_from_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/reopen_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/request_quote_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/update_event_details_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/update_party_item_use_case.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../party_fixtures.dart';

/// O salão do catálogo de demonstração, em miniatura: um serviço opcional
/// cobrado por pessoa, um por hora e uma taxa obrigatória.
PartyItemDraft venueDraft() {
  return buildDraft(
    externalId: 'listing-venue',
    category: PartyItemCategory.venue,
    name: 'Salão Glamour',
    priceCents: 170000,
    capacity: 120,
    ownServices: [
      buildDraft(
        ref: const ExternalRef.offer('offer-buffet'),
        category: PartyItemCategory.buffet,
        name: 'Buffet do salão',
        model: PricingModel.perPerson,
        priceCents: 4500,
      ),
      buildDraft(
        ref: const ExternalRef.offer('offer-animation'),
        category: PartyItemCategory.attraction,
        name: 'Animação da casa',
        model: PricingModel.perHour,
        priceCents: 18000,
      ),
      buildDraft(
        ref: const ExternalRef.offer('offer-cleaning'),
        name: 'Taxa de limpeza',
        priceCents: 15000,
        isRequired: true,
      ),
    ],
  );
}

/// O salão configurado, com os serviços [services] escolhidos (pelo id).
ConfiguredItem venueSelection({
  List<String> services = const ['offer-cleaning'],
  Map<String, Object?> configuration = kFourHours,
}) {
  final draft = venueDraft();
  return buildSelection(
    draft: draft,
    configuration: configuration,
    ownServices: [
      for (final service in draft.ownServices)
        if (services.contains(service.externalRef.id))
          buildSelection(
            draft: service,
            configuration: service.pricing.model == PricingModel.perHour
                ? const {'duration_hours': 2}
                : const {},
          ),
    ],
  );
}

void main() {
  const partyId = PartyId('party-1');
  const missingId = PartyId('nao-existe');

  late InMemoryPartyRepository repository;
  late AddItemToPartyUseCase addItem;
  late UpdatePartyItemUseCase updateItem;

  Matcher throwsPartyNotFound() => throwsA(isA<PartyNotFound>());

  Future<Party> createParty({DateTime? eventDate, int? guests = 80}) {
    return CreatePartyUseCase(repository, clock: fixedClock)(
      partyId: partyId,
      ownerId: 'user-1',
      details: buildDetails(eventDate: eventDate ?? kEventDay, guests: guests),
    );
  }

  Future<Party> stored() async => (await repository.getById(partyId))!;

  setUp(() {
    repository = InMemoryPartyRepository();
    final ids = sequentialIds();
    addItem = AddItemToPartyUseCase(repository, newId: ids);
    updateItem = UpdatePartyItemUseCase(repository, newId: ids);
  });

  group('montagem dos itens', () {
    test('o anúncio vem primeiro, e os serviços dele ligados a ele', () {
      final items = assembleItems(
        venueSelection(services: ['offer-buffet', 'offer-cleaning']),
        newId: sequentialIds(),
      );

      expect(items.map((item) => item.nameSnapshot), [
        'Salão Glamour',
        'Buffet do salão',
        'Taxa de limpeza',
      ]);
      expect(items[0].relation, const ItemRelation.independent());
      expect(items[0].capacity, 120);
      expect(items[1].relation, ItemRelation.linkedTo(items[0].id));
      expect(items[2].relation, ItemRelation.requiredBy(items[0].id));
      // A configuração já sai limpa e conferida.
      expect(items[0].configuration, ItemConfiguration(kFourHours));
    });

    test('um anúncio não entra sem os serviços obrigatórios dele', () {
      expect(
        () => assembleItems(
          venueSelection(services: const []),
          newId: sequentialIds(),
        ),
        throwsA(isA<RequiredItemMissing>()),
      );
    });

    test('um item indicado por outro guarda quem o indicou', () {
      final item = assembleItems(
        buildSelection(recommendedBy: 'venue-1'),
        newId: sequentialIds(),
      ).single;

      expect(
        item.relation,
        const ItemRelation.recommendedBy(PartyItemId('venue-1')),
      );
    });

    test('a configuração que não passa nas regras não vira item', () {
      expect(
        () => assembleItems(
          venueSelection(configuration: const {}),
          newId: sequentialIds(),
        ),
        throwsA(isA<InvalidItemConfiguration>()),
      );
      expect(
        () => assembleItems(
          buildSelection(
            draft: buildDraft(category: PartyItemCategory.dj),
            quantity: 2,
            configuration: kFourHours,
          ),
          newId: sequentialIds(),
        ),
        throwsA(isA<InvalidQuantity>()),
      );
    });
  });

  group('CreatePartyUseCase', () {
    test('grava a festa já em planejamento, com os dados do evento', () async {
      final party = await CreatePartyUseCase(repository, clock: fixedClock)(
        partyId: partyId,
        ownerId: 'user-1',
        details: buildDetails(
          title: 'Aniversário da Ana',
          eventType: 'kids_party',
          eventDate: kEventDay,
          guests: 30,
        ),
      );

      final saved = await stored();
      expect(saved.status, PartyStatus.planning);
      expect(saved.ownerId, 'user-1');
      expect(saved.title.value, 'Aniversário da Ana');
      expect(saved.eventType, 'kids_party');
      expect(saved.guestCount!.value, 30);
      // A festa pode nascer vazia.
      expect(party.budget.isEmpty, isTrue);
    });

    test('a data da festa nova precisa ser no futuro', () async {
      await expectLater(
        createParty(eventDate: kFixedNow.subtract(const Duration(days: 1))),
        throwsA(isA<EventDateInPast>()),
      );
      expect(await repository.getById(partyId), isNull);
    });
  });

  group('AddItemToPartyUseCase', () {
    test('põe o item configurado na festa e grava', () async {
      await createParty();

      final party = await addItem(
        partyId: partyId,
        selection: buildSelection(quantity: 3),
      );

      expect(party.budget.items.single.quantity.value, 3);
      expect((await stored()).budget.items, hasLength(1));
    });

    test('o salão entra com os serviços escolhidos', () async {
      await createParty();

      final party = await addItem(
        partyId: partyId,
        selection: venueSelection(
          services: ['offer-buffet', 'offer-animation', 'offer-cleaning'],
        ),
      );

      expect(party.budget.items, hasLength(4));
      // 1.700 + 45 x 80 + 180 x 2 h + 150
      expect(
        party.estimate.total,
        Money.fromCents(170000 + 360000 + 36000 + 15000),
      );
      expect(party.estimate.isComplete, isTrue);
    });

    test(
      'grava junto os dados do evento informados no mesmo formulário',
      () async {
        await createParty(guests: null);

        final party = await addItem(
          partyId: partyId,
          selection: venueSelection(),
          eventDetails: buildDetails(eventDate: kEventDay, guests: 100),
        );

        expect(party.guestCount!.value, 100);
        expect(party.budget.venue, isNotNull);
      },
    );

    test('se o item não pode entrar, a festa fica como estava', () async {
      await createParty(guests: null);

      await expectLater(
        addItem(
          partyId: partyId,
          selection: venueSelection(),
          // Mais gente do que o salão comporta.
          eventDetails: buildDetails(eventDate: kEventDay, guests: 500),
        ),
        throwsA(isA<GuestCountExceedsCapacity>()),
      );

      final saved = await stored();
      expect(saved.budget.isEmpty, isTrue);
      // Nem os dados do evento foram gravados pela metade.
      expect(saved.guestCount, isNull);
    });

    test('o mesmo anúncio não entra duas vezes', () async {
      await createParty();
      await addItem(partyId: partyId, selection: buildSelection());

      await expectLater(
        addItem(partyId: partyId, selection: buildSelection()),
        throwsA(isA<DuplicatePartyItem>()),
      );
    });

    test('cria a festa já com o item, em uma gravação só', () async {
      final party = await addItem.intoNewParty(
        create: CreatePartyUseCase(repository, clock: fixedClock),
        partyId: partyId,
        ownerId: 'user-1',
        eventDetails: buildDetails(eventDate: kEventDay, guests: 80),
        selection: venueSelection(),
      );

      expect(party.status, PartyStatus.planning);
      expect(party.budget.items, hasLength(2));
    });

    test(
      'se o primeiro item não pode entrar, a festa não chega a existir',
      () async {
        await expectLater(
          addItem.intoNewParty(
            create: CreatePartyUseCase(repository, clock: fixedClock),
            partyId: partyId,
            ownerId: 'user-1',
            // Sem a data e os convidados, o salão não entra.
            eventDetails: buildDetails(),
            selection: venueSelection(),
          ),
          throwsA(isA<EventDetailsRequired>()),
        );

        expect(await repository.getById(partyId), isNull);
      },
    );

    test('falha para festa inexistente', () async {
      await expectLater(
        addItem(partyId: missingId, selection: buildSelection()),
        throwsPartyNotFound(),
      );
    });
  });

  group('UpdatePartyItemUseCase', () {
    late PartyItemId venueId;

    Future<Party> withVenue({
      List<String> services = const ['offer-cleaning'],
    }) async {
      await createParty();
      final party = await addItem(
        partyId: partyId,
        selection: venueSelection(services: services),
      );
      venueId = party.budget.venue!.id;
      return party;
    }

    test('troca a configuração do item e grava', () async {
      await withVenue();

      final party = await updateItem(
        partyId: partyId,
        itemId: venueId,
        quantity: 1,
        configuration: const {'duration_hours': 6, 'notes': 'Chegar cedo'},
      );

      expect(
        party.budget.venue!.configuration,
        ItemConfiguration(const {'duration_hours': 6, 'notes': 'Chegar cedo'}),
      );
      expect((await stored()).budget.venue!.configuration.durationHours, 6);
    });

    test('sem a escolha dos serviços, eles não são tocados', () async {
      await withVenue(services: ['offer-buffet', 'offer-cleaning']);

      final party = await updateItem(
        partyId: partyId,
        itemId: venueId,
        quantity: 1,
        configuration: kFourHours,
      );

      expect(party.budget.items, hasLength(3));
    });

    test('a escolha dos serviços põe os novos e tira os que saíram', () async {
      await withVenue(services: ['offer-buffet', 'offer-cleaning']);
      final draft = venueDraft();

      final party = await updateItem(
        partyId: partyId,
        itemId: venueId,
        quantity: 1,
        configuration: kFourHours,
        ownServices: [
          // Sai o buffet, entra a animação; a taxa obrigatória continua.
          buildSelection(
            draft: draft.ownServices[1],
            configuration: const {'duration_hours': 3},
          ),
          buildSelection(draft: draft.ownServices[2]),
        ],
      );

      expect(party.budget.items.map((item) => item.nameSnapshot), [
        'Salão Glamour',
        'Taxa de limpeza',
        'Animação da casa',
      ]);
      final animation = party.budget.items.last;
      expect(animation.relation, ItemRelation.linkedTo(venueId));
      expect(animation.configuration.durationHours, 3);
    });

    test('um serviço obrigatório fica, mesmo fora da escolha', () async {
      await withVenue();

      final party = await updateItem(
        partyId: partyId,
        itemId: venueId,
        quantity: 1,
        configuration: kFourHours,
        ownServices: const [],
      );

      expect(party.budget.items.map((item) => item.nameSnapshot), [
        'Salão Glamour',
        'Taxa de limpeza',
      ]);
    });

    test(
      'um serviço que continua na escolha tem a configuração atualizada',
      () async {
        await withVenue(services: ['offer-animation', 'offer-cleaning']);
        final draft = venueDraft();

        final party = await updateItem(
          partyId: partyId,
          itemId: venueId,
          quantity: 1,
          configuration: kFourHours,
          ownServices: [
            buildSelection(
              draft: draft.ownServices[1],
              configuration: const {'duration_hours': 5},
            ),
            buildSelection(draft: draft.ownServices[2]),
          ],
        );

        expect(party.budget.items, hasLength(3));
        final animation = party.budget.findByExternalRef(
          const ExternalRef.offer('offer-animation'),
        )!;
        expect(animation.configuration.durationHours, 5);
      },
    );

    test(
      'um serviço que saiu do catálogo só sai quando a pessoa o remove',
      () async {
        // O serviço que o item referenciava deixou de existir: ele não aparece
        // mais na escolha, e não pode sumir da festa em silêncio.
        final party = planningParty(
          items: [
            buildVenue(),
            buildOwnService(
              ref: const ExternalRef.unavailable('service-1'),
              name: 'Serviço que saiu',
              category: PartyItemCategory.other,
              model: PricingModel.fixed,
            ),
          ],
        );
        await repository.save(party);

        final saved = await updateItem(
          partyId: partyId,
          itemId: const PartyItemId('venue-1'),
          quantity: 1,
          configuration: kFourHours,
          ownServices: const [],
        );

        expect(saved.budget.items, hasLength(2));
      },
    );

    test('se a nova configuração não passa, nada é gravado', () async {
      await withVenue();

      await expectLater(
        updateItem(
          partyId: partyId,
          itemId: venueId,
          quantity: 1,
          configuration: const {},
        ),
        throwsA(isA<InvalidItemConfiguration>()),
      );

      expect((await stored()).budget.venue!.configuration.durationHours, 4);
    });

    test('falha para festa inexistente', () async {
      await expectLater(
        updateItem(
          partyId: missingId,
          itemId: const PartyItemId('x'),
          quantity: 1,
          configuration: const {},
        ),
        throwsPartyNotFound(),
      );
    });
  });

  group('RemoveItemFromPartyUseCase', () {
    test('tira o item e diz o que saiu junto', () async {
      await createParty();
      final added = await addItem(
        partyId: partyId,
        selection: venueSelection(),
      );

      final result = await RemoveItemFromPartyUseCase(repository)(
        partyId: partyId,
        itemId: added.budget.venue!.id,
      );

      expect(result.removal.removedWith.single.nameSnapshot, 'Taxa de limpeza');
      expect(result.party.budget.isEmpty, isTrue);
    });

    test('a festa continua existindo sem itens', () async {
      await createParty();
      final added = await addItem(
        partyId: partyId,
        selection: buildSelection(),
      );

      await RemoveItemFromPartyUseCase(repository)(
        partyId: partyId,
        itemId: added.budget.items.single.id,
      );

      final saved = await stored();
      expect(saved.budget.isEmpty, isTrue);
      expect(saved.status, PartyStatus.planning);
    });

    test('falha para festa inexistente', () async {
      await expectLater(
        RemoveItemFromPartyUseCase(repository)(
          partyId: missingId,
          itemId: const PartyItemId('x'),
        ),
        throwsPartyNotFound(),
      );
    });
  });

  group('UpdateEventDetailsUseCase', () {
    test('troca os dados do evento e grava', () async {
      await createParty();

      final party = await UpdateEventDetailsUseCase(repository)(
        partyId: partyId,
        details: buildDetails(
          title: 'Casamento',
          eventType: 'wedding',
          eventDate: kEventDay,
          guests: 150,
        ),
      );

      expect(party.title.value, 'Casamento');
      expect((await stored()).guestCount!.value, 150);
    });

    test('falha para festa inexistente', () async {
      await expectLater(
        UpdateEventDetailsUseCase(repository)(
          partyId: missingId,
          details: buildDetails(),
        ),
        throwsPartyNotFound(),
      );
    });
  });

  group('o caminho do orçamento', () {
    Future<Party> requested() async {
      await createParty();
      await addItem(partyId: partyId, selection: buildSelection());
      return RequestQuoteUseCase(repository)(partyId);
    }

    /// O fornecedor responde: é o que o modo demonstração faz por baixo.
    Future<void> vendorQuotes(int cents) async {
      final party = await stored();
      for (final item in party.budget.items) {
        party.registerVendorResponse(
          item.id,
          VendorResponse.quote(Money.fromCents(cents)),
        );
      }
      await repository.save(party);
    }

    test('solicitar grava a festa com o orçamento solicitado', () async {
      final party = await requested();

      expect(party.status, PartyStatus.locked);
      expect((await stored()).quoteRound, 1);
      expect(
        (await stored()).budget.items.single.quote.status,
        QuoteStatus.pending,
      );
    });

    test('solicitar barra a festa que ainda tem pendência', () async {
      await createParty(guests: null);
      await addItem(partyId: partyId, selection: buildSelection());

      await expectLater(
        RequestQuoteUseCase(repository)(partyId),
        throwsA(isA<GuestCountRequired>()),
      );
      expect((await stored()).status, PartyStatus.planning);
    });

    test('um rascunho passa para o planejamento antes de pedir', () async {
      // Uma festa criada por uma versão antiga do app pode estar como
      // rascunho; a API só aceita um passo por gravação.
      await repository.save(
        buildParty()
          ..updateEventDetails(buildDetails(eventDate: kEventDay, guests: 80))
          ..addItems([buildItem()]),
      );

      final party = await RequestQuoteUseCase(repository)(partyId);

      expect(party.status, PartyStatus.locked);
    });

    test(
      'voltar a editar, alterar e pedir de novo é a segunda rodada',
      () async {
        await requested();
        await vendorQuotes(90000);

        final reopened = await ReopenPartyUseCase(repository)(partyId);
        expect(reopened.status, PartyStatus.planning);

        await updateItem(
          partyId: partyId,
          itemId: reopened.budget.items.single.id,
          quantity: 5,
          configuration: const {},
        );
        final again = await RequestQuoteUseCase(repository)(partyId);

        expect(again.quoteRound, 2);
        expect(again.status, PartyStatus.locked);
      },
    );

    test('aceitar só depois que os fornecedores responderam', () async {
      await requested();

      await expectLater(
        ConfirmQuoteUseCase(repository)(partyId),
        throwsA(isA<InvalidPartyTransition>()),
      );

      await vendorQuotes(90000);
      final party = await ConfirmQuoteUseCase(repository)(partyId);

      expect(party.status, PartyStatus.confirmed);
      expect((await stored()).status, PartyStatus.confirmed);
    });

    test('cancelar grava a festa como cancelada', () async {
      await requested();

      final party = await CancelPartyUseCase(repository)(partyId);

      expect(party.status, PartyStatus.cancelled);
      expect((await stored()).status, PartyStatus.cancelled);
    });

    test('os casos de uso falham para festa inexistente', () async {
      await expectLater(
        RequestQuoteUseCase(repository)(missingId),
        throwsPartyNotFound(),
      );
      await expectLater(
        ReopenPartyUseCase(repository)(missingId),
        throwsPartyNotFound(),
      );
      await expectLater(
        ConfirmQuoteUseCase(repository)(missingId),
        throwsPartyNotFound(),
      );
      await expectLater(
        CancelPartyUseCase(repository)(missingId),
        throwsPartyNotFound(),
      );
    });
  });

  group('DeletePartyUseCase', () {
    test('apaga uma festa em planejamento', () async {
      await createParty();

      await DeletePartyUseCase(repository)(partyId);

      expect(await repository.getById(partyId), isNull);
    });

    test('com o orçamento solicitado, pede o cancelamento antes', () async {
      await createParty();
      await addItem(partyId: partyId, selection: buildSelection());
      await RequestQuoteUseCase(repository)(partyId);

      await expectLater(
        DeletePartyUseCase(repository)(partyId),
        throwsA(isA<PartyHasOpenQuote>()),
      );
      expect(await repository.getById(partyId), isNotNull);

      await CancelPartyUseCase(repository)(partyId);
      await DeletePartyUseCase(repository)(partyId);
      expect(await repository.getById(partyId), isNull);
    });

    test('apagar o que já não existe não é erro', () async {
      await DeletePartyUseCase(repository)(missingId);
    });
  });

  group('InMemoryPartyRepository', () {
    test('guarda e devolve cópias: só o que é gravado fica', () async {
      await createParty();
      await addItem(partyId: partyId, selection: buildSelection());

      // Uma alteração que não passa por save não chega ao que está guardado.
      final loaded = await stored();
      loaded.removeItem(loaded.budget.items.single.id);

      expect((await stored()).budget.items, hasLength(1));
    });

    test('lista as festas da conta, da gravação mais recente para a mais '
        'antiga', () async {
      await repository.save(buildParty(id: 'a', title: 'Primeira'));
      await repository.save(buildParty(id: 'b', title: 'Segunda'));
      await repository.save(buildParty(id: 'c', ownerId: 'outra-conta'));
      await repository.save(buildParty(id: 'a', title: 'Primeira, alterada'));

      final parties = await repository.listByOwner('user-1');

      expect(parties.map((party) => party.title.value), [
        'Primeira, alterada',
        'Segunda',
      ]);
      expect(repository.all(), hasLength(3));
    });
  });
}
