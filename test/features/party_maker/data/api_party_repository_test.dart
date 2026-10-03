import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/data/party_mapper.dart';
import 'package:yvenist/features/party_maker/data/repositories/api_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

import '../../../support/fake_api.dart';
import '../party_fixtures.dart';
import 'party_json.dart';

void main() {
  group('partyFromJson', () {
    test('converte a festa, o evento e o item copiado do catálogo', () {
      final party = partyFromJson(
        partyJson(eventType: 'wedding', eventAt: '2027-01-01T22:00:00Z'),
      );

      expect(party.id, const PartyId(partyId));
      expect(party.ownerId, 'user-1');
      expect(party.title.value, '15 anos da Maria');
      expect(party.status, PartyStatus.planning);
      expect(party.eventType, 'wedding');
      expect(party.eventDate, EventDate(DateTime.utc(2027, 1, 1, 22)));
      expect(party.guestCount, GuestCount(80));
      expect(party.quoteRound, 0);
      expect(party.createdAt, DateTime.utc(2026, 10, 1, 12));
      expect(party.updatedAt, DateTime.utc(2026, 10, 1, 12, 30));

      final item = party.budget.items.single;
      expect(item.id, const PartyItemId(itemId));
      expect(item.externalRef.isListing, isTrue);
      expect(item.externalRef.id, listingId);
      expect(item.category, PartyItemCategory.venue);
      expect(item.nameSnapshot, 'Salão Glamour 8');
      expect(item.pricing.model, PricingModel.fixed);
      expect(item.pricing.amount, Money.fromCents(170000));
      expect(item.quantity.value, 1);
      expect(item.configuration, ItemConfiguration(kFourHours));
      expect(item.relation, const ItemRelation.independent());
      expect(item.quote.status, QuoteStatus.none);
      expect(item.imageUrlSnapshot, 'https://example.com/capa.jpg');
      expect(item.capacity, 120);
      expect(item.vendorId, vendorId);
    });

    test('lê todos os status', () {
      for (final status in PartyStatus.values) {
        expect(
          partyFromJson(partyJson(status: status.apiValue)).status,
          status,
        );
      }
    });

    test('status que o app não conhece não vira uma festa', () {
      // Falhar fechado: sem saber em que pé a festa está, o app não sabe o
      // que pode ser feito com ela.
      expect(
        () => partyFromJson(partyJson(status: 'archived')),
        throwsFormatException,
      );
    });

    test('categoria que o app não conhece vira "other"', () {
      final party = partyFromJson(
        partyJson(items: [itemJson(category: 'categoria_nova')]),
      );

      expect(party.budget.items.single.category, PartyItemCategory.other);
    });

    test('item sob consulta chega sem preço, e não com zero', () {
      final party = partyFromJson(
        partyJson(
          items: [itemJson(pricingModel: 'on_request', unitPriceCents: null)],
        ),
      );

      final item = party.budget.items.single;
      expect(item.pricing.isOnRequest, isTrue);
      expect(item.pricing.amount, isNull);
      expect(item.estimate(guests: 80), isNull);
    });

    test('forma de cobrança que o app não conhece vira sob consulta', () {
      // Sem saber como o preço é cobrado, o app não estima.
      final party = partyFromJson(
        partyJson(items: [itemJson(pricingModel: 'per_galaxy')]),
      );

      expect(party.budget.items.single.pricing.isOnRequest, isTrue);
      expect(party.estimate.unpricedItems, 1);
    });

    test('lê o serviço próprio e a que item ele se liga', () {
      final party = partyFromJson(
        partyJson(
          items: [
            itemJson(),
            itemJson(
              id: serviceId,
              listing: null,
              offer: offerId,
              parent: itemId,
              relation: 'required',
              category: 'other',
              name: 'Taxa de limpeza',
              unitPriceCents: 15000,
              configuration: const {},
            ),
          ],
        ),
      );

      final service = party.budget.items.last;
      expect(service.externalRef.isOffer, isTrue);
      expect(service.externalRef.id, offerId);
      expect(
        service.relation,
        const ItemRelation.requiredBy(PartyItemId(itemId)),
      );
    });

    test('item cuja origem saiu do catálogo continua na festa', () {
      final party = partyFromJson(
        partyJson(items: [itemJson(listing: null)]),
        clock: fixedClock,
      );

      final item = party.budget.items.single;
      expect(item.nameSnapshot, 'Salão Glamour 8');
      expect(item.externalRef.isAvailable, isFalse);
      expect(party.quoteBlockers.single.code, 'item_no_longer_available');
    });

    test('lê a resposta do fornecedor de cada item', () {
      final party = partyFromJson(
        partyJson(
          status: 'quoted',
          quoteRound: 1,
          items: [
            itemJson(
              quote: quoteJson(
                status: 'quoted',
                amountCents: 180000,
                message: 'Com limpeza incluída',
                respondedAt: '2026-10-02T09:00:00Z',
              ),
            ),
          ],
        ),
      );

      final quote = party.budget.items.single.quote;
      expect(quote.status, QuoteStatus.quoted);
      expect(quote.amount, Money.fromCents(180000));
      expect(quote.message, 'Com limpeza incluída');
      expect(quote.respondedAt, DateTime.utc(2026, 10, 2, 9));
      expect(party.quotedTotal, Money.fromCents(180000));
      expect(party.quoteRound, 1);
    });

    test('lê o retrato do pedido de orçamento', () {
      final party = partyFromJson(
        partyJson(
          status: 'locked',
          snapshot: {
            'generated_at': '2026-10-01T13:00:00Z',
            'expires_at': null,
            'total_cents': 170000,
            'currency': 'BRL',
            'breakdown': [
              {
                'listing_id': listingId,
                'offer_id': null,
                'category': 'venue',
                'name': 'Salão Glamour 8',
                'pricing_model': 'fixed',
                'unit_price_cents': 170000,
                'quantity': 1,
                'subtotal_cents': 170000,
              },
              {
                'listing_id': 'outro',
                'offer_id': null,
                'category': 'decoration',
                'name': 'Decoração sob consulta',
                'pricing_model': 'on_request',
                'unit_price_cents': 0,
                'quantity': 1,
                'subtotal_cents': null,
              },
            ],
          },
        ),
      );

      final snapshot = party.quoteSnapshot!;
      expect(snapshot.requestedAt, DateTime.utc(2026, 10, 1, 13));
      expect(snapshot.estimatedTotal, Money.fromCents(170000));
      expect(snapshot.unpricedItems, 1);
    });

    test('lê o histórico, e pula o que o app ainda não conhece', () {
      final party = partyFromJson(
        partyJson(
          history: [
            historyJson(kind: 'quote_requested', amountCents: 170000),
            historyJson(kind: 'algo_novo'),
            historyJson(
              kind: 'vendor_requested_changes',
              actor: 'vendor',
              itemId: itemId,
              itemName: 'Salão Glamour 8',
              message: 'Só até 100 pessoas.',
            ),
          ],
        ),
      );

      expect(party.history.map((entry) => entry.kind), [
        PartyHistoryKind.quoteRequested,
        PartyHistoryKind.vendorRequestedChanges,
      ]);
      final answer = party.history.last;
      expect(answer.actor, PartyHistoryActor.vendor);
      expect(answer.itemId, const PartyItemId(itemId));
      expect(answer.itemName, 'Salão Glamour 8');
      expect(answer.message, 'Só até 100 pessoas.');
      expect(party.history.first.amount, Money.fromCents(170000));
    });

    test('configuração com um valor que o app não sabe mostrar fica de '
        'fora', () {
      final party = partyFromJson(
        partyJson(
          items: [
            itemJson(
              configuration: {
                'duration_hours': 4,
                'notes': 'Chegar cedo',
                'extras': ['a', 'b'],
              },
            ),
          ],
        ),
      );

      expect(
        party.budget.items.single.configuration,
        ItemConfiguration(const {'duration_hours': 4, 'notes': 'Chegar cedo'}),
      );
    });
  });

  group('partyToJson', () {
    test('envia o estado desejado, sem nome nem preço dos itens', () {
      final party = partyFromJson(
        partyJson(eventType: 'wedding', eventAt: '2027-01-01T22:00:00Z'),
      );

      final json = partyToJson(party, version: 4);

      expect(json, {
        'title': '15 anos da Maria',
        'event_type': 'wedding',
        'event_at': '2027-01-01T22:00:00.000Z',
        'guest_count': 80,
        'status': 'planning',
        'items': [
          {
            'id': itemId,
            'listing_id': listingId,
            'offer_id': null,
            'parent_item_id': null,
            'quantity': 1,
            'configuration': {'duration_hours': 4},
          },
        ],
        'version': 4,
      });
    });

    test('festa nova não envia versão', () {
      final json = partyToJson(partyFromJson(partyJson()), version: null);

      expect(json.containsKey('version'), isFalse);
    });

    test('a data do evento vai em UTC', () {
      final party = partyFromJson(partyJson(eventAt: null), clock: fixedClock)
        ..updateEventDetails(
          buildDetails(
            title: '15 anos da Maria',
            eventDate: DateTime.utc(2027, 1, 1, 22).toLocal(),
            guests: 80,
          ),
        );

      expect(
        partyToJson(party, version: 1)['event_at'],
        '2027-01-01T22:00:00.000Z',
      );
    });

    test('o serviço próprio vai com a origem e o item a que se liga', () {
      final party = partyFromJson(
        partyJson(
          items: [
            itemJson(),
            itemJson(
              id: serviceId,
              listing: null,
              offer: offerId,
              parent: itemId,
              relation: 'linked',
              category: 'buffet',
              configuration: const {},
            ),
          ],
        ),
      );

      final items = (partyToJson(party, version: 1)['items'] as List)
          .cast<Map<String, Object?>>();

      expect(items.last, {
        'id': serviceId,
        'listing_id': null,
        'offer_id': offerId,
        'parent_item_id': itemId,
        'quantity': 1,
        'configuration': <String, Object>{},
      });
      // A relação não é enviada: quem decide se o serviço é obrigatório é o
      // servidor, pelo catálogo.
      expect(items.last.containsKey('relation'), isFalse);
    });

    test('item cuja origem saiu do catálogo vai sem id de origem', () {
      final party = partyFromJson(partyJson(items: [itemJson(listing: null)]));

      final item = (partyToJson(party, version: 1)['items'] as List).single;

      expect((item as Map)['listing_id'], isNull);
      expect(item['offer_id'], isNull);
    });

    test('"orçamento recebido" e "edição solicitada" nunca são enviados', () {
      // São status que só a resposta de um fornecedor produz: o que o cliente
      // pede é "orçamento solicitado", e o servidor decide o resto.
      for (final status in ['quoted', 'edit_requested']) {
        final party = partyFromJson(partyJson(status: status));

        expect(partyToJson(party, version: 1)['status'], 'locked');
      }
      for (final status in ['planning', 'locked', 'confirmed', 'cancelled']) {
        final party = partyFromJson(partyJson(status: status));

        expect(partyToJson(party, version: 1)['status'], status);
      }
    });
  });

  group('ApiPartyRepository', () {
    late FakeApi api;
    late ApiPartyRepository repository;

    setUp(() {
      api = FakeApi();
      repository = ApiPartyRepository(api.client, clock: fixedClock);
    });

    test('lista as festas da conta autenticada', () async {
      api.reply('GET', '/parties', {
        'items': [
          partyJson(),
          partyJson(id: 'outra-festa', title: 'Casamento'),
        ],
      });

      final parties = await repository.listByOwner('user-1');

      expect(parties.map((p) => p.title.value), [
        '15 anos da Maria',
        'Casamento',
      ]);
      expect(api.lastRequest.headers['Authorization'], 'Bearer acesso');
    });

    test(
      'getById usa o que a listagem já trouxe, sem nova requisição',
      () async {
        api.reply('GET', '/parties', {
          'items': [partyJson()],
        });
        await repository.listByOwner('user-1');

        final party = await repository.getById(const PartyId(partyId));

        expect(party!.title.value, '15 anos da Maria');
        expect(api.calls, ['GET /parties']);
      },
    );

    test('cada leitura devolve uma instância nova', () async {
      // Se uma gravação falhar, a alteração feita na instância anterior não
      // pode "vazar" para a próxima leitura.
      api.reply('GET', '/parties', {
        'items': [partyJson()],
      });
      await repository.listByOwner('user-1');

      final first = await repository.getById(const PartyId(partyId));
      first!.removeItem(const PartyItemId(itemId));
      final second = await repository.getById(const PartyId(partyId));

      expect(second, isNot(same(first)));
      expect(second!.budget.items, hasLength(1));
    });

    test('festa que não está em cache é buscada no servidor', () async {
      api.reply('GET', '/parties/$partyId', partyJson());

      final party = await repository.getById(const PartyId(partyId));

      expect(party!.id.value, partyId);
      expect(api.calls, ['GET /parties/$partyId']);
    });

    test('festa inexistente devolve null', () async {
      api.fail(
        'GET',
        '/parties/$partyId',
        404,
        'party_not_found',
        'Não existe.',
      );

      expect(await repository.getById(const PartyId(partyId)), isNull);
    });

    test(
      'criar não envia versão e devolve a festa como o servidor gravou',
      () async {
        // O app enviou o que tinha; o servidor respondeu com o preço do
        // catálogo.
        api.reply(
          'PUT',
          '/parties/$partyId',
          partyJson(items: [itemJson(unitPriceCents: 199900)]),
          status: 201,
        );
        final local = partyFromJson(
          partyJson(items: [itemJson(unitPriceCents: 1)]),
        );

        final saved = await repository.save(local);

        expect(api.lastBody.containsKey('version'), isFalse);
        expect(saved, isNot(same(local)));
        expect(
          saved.budget.items.single.pricing.amount,
          Money.fromCents(199900),
        );
      },
    );

    test('atualizar envia a versão conhecida e passa a usar a nova', () async {
      api.reply('PUT', '/parties/$partyId', partyJson(version: 1), status: 201);
      final created = await repository.save(partyFromJson(partyJson()));

      api.reply(
        'PUT',
        '/parties/$partyId',
        partyJson(version: 2, status: 'locked', quoteRound: 1),
      );
      created.requestQuote();
      await repository.save(created);
      expect(api.lastBody['version'], 1);
      expect(api.lastBody['status'], 'locked');

      api.reply('PUT', '/parties/$partyId', partyJson(version: 3));
      final reloaded = await repository.getById(const PartyId(partyId));
      await repository.save(reloaded!);
      expect(api.lastBody['version'], 2);
    });

    test(
      'conflito de versão faz a próxima leitura buscar de novo no servidor',
      () async {
        api.reply('GET', '/parties', {
          'items': [partyJson()],
        });
        await repository.listByOwner('user-1');
        api.fail(
          'PUT',
          '/parties/$partyId',
          409,
          'party_version_conflict',
          'A festa foi alterada em outro dispositivo.',
        );
        final party = await repository.getById(const PartyId(partyId));

        await expectLater(
          repository.save(party!),
          throwsA(
            isA<ConflictFailure>().having(
              (f) => f.code,
              'code',
              'party_version_conflict',
            ),
          ),
        );

        // É também o que acontece quando um fornecedor responde: a cópia
        // local fica para trás, e a próxima leitura traz a resposta.
        api.reply(
          'GET',
          '/parties/$partyId',
          partyJson(version: 5, title: 'Do tablet'),
        );
        final fresh = await repository.getById(const PartyId(partyId));
        expect(fresh!.title.value, 'Do tablet');
      },
    );

    test(
      'falha de rede ao gravar mantém a cópia confirmada pelo servidor',
      () async {
        api.reply('GET', '/parties', {
          'items': [partyJson()],
        });
        await repository.listByOwner('user-1');
        api.on(
          'PUT',
          '/parties/$partyId',
          (_) => throw http.ClientException('sem conexão'),
        );
        final party = await repository.getById(const PartyId(partyId));
        party!.removeItem(const PartyItemId(itemId));

        await expectLater(
          repository.save(party),
          throwsA(isA<NetworkFailure>()),
        );

        // A remoção não chegou ao servidor: a próxima leitura ainda tem o item.
        final again = await repository.getById(const PartyId(partyId));
        expect(again!.budget.items, hasLength(1));
        expect(api.calls.where((call) => call.startsWith('GET')), hasLength(1));
      },
    );

    test('uma regra recusada pelo servidor chega com o código dela', () async {
      api.fail(
        'PUT',
        '/parties/$partyId',
        422,
        'guest_count_exceeds_capacity',
        'O espaço escolhido comporta até 120 pessoas.',
      );

      await expectLater(
        repository.save(partyFromJson(partyJson())),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', 'guest_count_exceeds_capacity')
              .having(
                (f) => f.message,
                'message',
                'O espaço escolhido comporta até 120 pessoas.',
              ),
        ),
      );
    });

    test('apagar remove do servidor e do cache', () async {
      api
        ..reply('GET', '/parties', {
          'items': [partyJson()],
        })
        ..replyEmpty('DELETE', '/parties/$partyId')
        ..fail(
          'GET',
          '/parties/$partyId',
          404,
          'party_not_found',
          'Não existe.',
        );
      await repository.listByOwner('user-1');

      await repository.deleteById(const PartyId(partyId));

      expect(await repository.getById(const PartyId(partyId)), isNull);
      expect(api.calls, contains('DELETE /parties/$partyId'));
    });

    test('apagar o que já não existe não é erro', () async {
      api.fail(
        'DELETE',
        '/parties/$partyId',
        404,
        'party_not_found',
        'Não existe.',
      );

      await repository.deleteById(const PartyId(partyId));
    });

    test('apagar uma festa com o orçamento solicitado é recusado', () async {
      api.fail(
        'DELETE',
        '/parties/$partyId',
        409,
        'party_has_open_quote',
        'Cancele a festa antes de apagar.',
      );

      await expectLater(
        repository.deleteById(const PartyId(partyId)),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'party_has_open_quote',
          ),
        ),
      );
    });
  });
}
