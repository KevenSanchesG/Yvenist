import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/party_maker/data/party_mapper.dart';
import 'package:yvenist/features/party_maker/data/repositories/api_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

import '../../../support/fake_api.dart';

const String partyId = '11111111-2222-3333-4444-555555555555';
const String itemId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const String listingId = '6d4c9d3f-0da9-4f27-9bb8-b158a61bdea5';

Map<String, dynamic> itemJson({
  String id = itemId,
  String? listing = listingId,
  String category = 'venue',
  String name = 'Salão Glamour 8',
  int unitPriceCents = 170000,
  int quantity = 1,
}) {
  return {
    'id': id,
    'listing_id': listing,
    'category': category,
    'name': name,
    'unit_price_cents': unitPriceCents,
    'currency': 'BRL',
    'quantity': quantity,
    'image_url': 'https://example.com/capa.jpg',
  };
}

Map<String, dynamic> partyJson({
  String id = partyId,
  String title = '15 anos da Maria',
  String status = 'planning',
  int version = 1,
  List<Map<String, dynamic>>? items,
  Map<String, dynamic>? snapshot,
}) {
  return {
    'id': id,
    'owner_id': 'user-1',
    'title': title,
    'event_at': null,
    'guest_count': null,
    'status': status,
    'version': version,
    'items': items ?? [itemJson()],
    'total_cents': 170000,
    'currency': 'BRL',
    'snapshot': snapshot,
    'created_at': '2026-10-01T12:00:00Z',
    'updated_at': '2026-10-01T12:30:00Z',
  };
}

void main() {
  group('partyFromJson', () {
    test('converte a festa e os itens copiados do catálogo', () {
      final party = partyFromJson(partyJson());

      expect(party.id, const PartyId(partyId));
      expect(party.ownerId, 'user-1');
      expect(party.title.value, '15 anos da Maria');
      expect(party.status, PartyStatus.planning);
      expect(party.createdAt, DateTime.utc(2026, 10, 1, 12));
      expect(party.updatedAt, DateTime.utc(2026, 10, 1, 12, 30));

      final item = party.budget.items.single;
      expect(item.id, const PartyItemId(itemId));
      expect(item.externalRef.source, 'vendor_catalog');
      expect(item.externalRef.id, listingId);
      expect(item.category, PartyItemCategory.venue);
      expect(item.nameSnapshot, 'Salão Glamour 8');
      expect(item.unitPriceSnapshot, Money.fromCents(170000));
      expect(item.quantity, Quantity(1));
      expect(item.imageUrlSnapshot, 'https://example.com/capa.jpg');
      expect(party.budget.total, Money.fromCents(170000));
    });

    test('converte data, convidados e todos os status', () {
      final json = partyJson()
        ..['event_at'] = '2027-01-01T22:00:00Z'
        ..['guest_count'] = 80;

      final party = partyFromJson(json);

      expect(party.eventDate, EventDate(DateTime.utc(2027, 1, 1, 22)));
      expect(party.guestCount, GuestCount(80));
      for (final status in PartyStatus.values) {
        expect(partyFromJson(partyJson(status: status.name)).status, status);
      }
    });

    test('categoria que o app não conhece vira "other"', () {
      final party = partyFromJson(
        partyJson(items: [itemJson(category: 'categoria_nova')]),
      );

      expect(party.budget.items.single.category, PartyItemCategory.other);
    });

    test('converte o snapshot do orçamento', () {
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
                'category': 'venue',
                'name': 'Salão Glamour 8',
                'unit_price_cents': 170000,
                'quantity': 1,
                'subtotal_cents': 170000,
              },
            ],
          },
        ),
      );

      final snapshot = party.paymentSnapshot!;
      expect(party.status, PartyStatus.locked);
      expect(snapshot.partyId, const PartyId(partyId));
      expect(snapshot.generatedAt, DateTime.utc(2026, 10, 1, 13));
      expect(snapshot.totalAmount, Money.fromCents(170000));
      expect(snapshot.breakdown.single.nameSnapshot, 'Salão Glamour 8');
      expect(snapshot.breakdown.single.subtotal, Money.fromCents(170000));
    });

    test('item cujo anúncio foi apagado continua na festa', () {
      final party = partyFromJson(partyJson(items: [itemJson(listing: null)]));

      final item = party.budget.items.single;
      expect(item.nameSnapshot, 'Salão Glamour 8');
      expect(item.externalRef.id, 'removed:$itemId');
    });
  });

  group('partyToJson', () {
    test('envia o estado desejado, sem nome nem preço dos itens', () {
      final party = partyFromJson(partyJson(items: [itemJson(quantity: 3)]));

      final json = partyToJson(party, version: 4);

      expect(json, {
        'title': '15 anos da Maria',
        'event_at': null,
        'guest_count': null,
        'status': 'planning',
        'items': [
          {'id': itemId, 'listing_id': listingId, 'quantity': 3},
        ],
        'version': 4,
      });
    });

    test('festa nova não envia versão', () {
      final json = partyToJson(partyFromJson(partyJson()), version: null);

      expect(json.containsKey('version'), isFalse);
    });

    test('data do evento vai em UTC', () {
      final party = partyFromJson(partyJson())
        ..setEventDate(EventDate(DateTime.utc(2027, 1, 1, 22)));

      expect(
        partyToJson(party, version: 1)['event_at'],
        '2027-01-01T22:00:00.000Z',
      );
    });

    test('item órfão é enviado sem id de anúncio', () {
      final party = partyFromJson(partyJson(items: [itemJson(listing: null)]));

      final items = partyToJson(party, version: 1)['items'] as List;

      expect((items.single as Map)['listing_id'], isNull);
    });
  });

  group('ApiPartyRepository', () {
    late FakeApi api;
    late ApiPartyRepository repository;

    setUp(() {
      api = FakeApi();
      repository = ApiPartyRepository(api.client);
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
        // O app enviou um preço local; o servidor respondeu com o do catálogo.
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
          saved.budget.items.single.unitPriceSnapshot,
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
        partyJson(version: 2, status: 'locked'),
      );
      created.lockForPayment();
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
  });
}
