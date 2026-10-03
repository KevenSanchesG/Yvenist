import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/data/party_mapper.dart';
import 'package:yvenist/features/party_maker/data/repositories/api_quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../../../support/fake_api.dart';
import '../party_fixtures.dart';
import 'party_json.dart';

const String _path = '/vendors/me/quote-requests';

void main() {
  group('quoteRequestFromJson', () {
    test('converte o pedido: o evento, o item e a resposta', () {
      final request = quoteRequestFromJson(
        quoteRequestJson(
          quote: quoteJson(
            status: 'quoted',
            amountCents: 180000,
            message: 'Com limpeza',
            respondedAt: '2026-10-02T09:00:00Z',
          ),
        ),
      );

      expect(request.itemId, itemId);
      expect(request.partyId, partyId);
      expect(request.partyStatus, PartyStatus.locked);
      expect(request.round, 1);
      expect(request.eventType, 'wedding');
      expect(request.eventDate, DateTime.utc(2026, 12, 25, 22));
      expect(request.guestCount, 80);
      expect(request.name, 'Salão Glamour 8');
      expect(request.category, PartyItemCategory.venue);
      expect(request.pricing.model, PricingModel.fixed);
      expect(request.pricing.amount, Money.fromCents(170000));
      expect(request.quantity, 1);
      expect(request.configuration, ItemConfiguration(kFourHours));
      expect(request.estimate, Money.fromCents(170000));
      expect(request.quote.status, QuoteStatus.quoted);
      expect(request.quote.amount, Money.fromCents(180000));
      expect(request.quote.message, 'Com limpeza');
      expect(request.canRespond, isTrue);
    });

    test('um serviço próprio traz o anúncio a que pertence', () {
      final request = quoteRequestFromJson(
        quoteRequestJson(
          relation: 'required',
          parentName: 'Salão Glamour 8',
          category: 'other',
          name: 'Taxa de limpeza',
          configuration: const {},
        ),
      );

      expect(request.relation, ItemRelationKind.required);
      expect(request.parentName, 'Salão Glamour 8');
      // Os campos são os de um serviço próprio, e não os da categoria.
      expect(request.spec.fields.map((field) => field.key), ['notes']);
    });

    test('item sob consulta chega sem preço e sem estimativa', () {
      final request = quoteRequestFromJson(
        quoteRequestJson(
          pricingModel: 'on_request',
          unitPriceCents: null,
          estimateCents: null,
        ),
      );

      expect(request.pricing.isOnRequest, isTrue);
      expect(request.estimate, isNull);
    });

    test('depois que o cliente aceita ou cancela, não dá mais para '
        'responder', () {
      for (final status in ['confirmed', 'cancelled']) {
        final request = quoteRequestFromJson(
          quoteRequestJson(partyStatus: status),
        );

        expect(request.canRespond, isFalse, reason: status);
      }
      for (final status in ['locked', 'quoted', 'edit_requested']) {
        final request = quoteRequestFromJson(
          quoteRequestJson(partyStatus: status),
        );

        expect(request.canRespond, isTrue, reason: status);
      }
    });
  });

  group('ApiQuoteInboxRepository', () {
    late FakeApi api;
    late ApiQuoteInboxRepository repository;

    setUp(() {
      api = FakeApi();
      repository = ApiQuoteInboxRepository(api.client);
    });

    test('lista os pedidos da conta autenticada', () async {
      api.reply('GET', _path, {
        'items': [
          quoteRequestJson(),
          quoteRequestJson(item: serviceId, name: 'Taxa de limpeza'),
        ],
      });

      final requests = await repository.list();

      expect(requests.map((request) => request.name), [
        'Salão Glamour 8',
        'Taxa de limpeza',
      ]);
      expect(api.lastRequest.headers['Authorization'], 'Bearer acesso');
    });

    test(
      'conta sem cadastro de fornecedor não tem pedidos a mostrar',
      () async {
        api.fail(
          'GET',
          _path,
          404,
          'vendor_profile_not_found',
          'Você ainda não tem um cadastro de fornecedor.',
        );

        await expectLater(repository.list(), throwsA(isA<NotFoundFailure>()));
      },
    );

    test('informar o valor envia os centavos e a mensagem', () async {
      api.reply(
        'POST',
        '$_path/$itemId/quote',
        quoteRequestJson(
          partyStatus: 'quoted',
          quote: quoteJson(status: 'quoted', amountCents: 180000),
        ),
      );

      final request = await repository.respond(
        itemId,
        VendorResponse.quote(Money.fromCents(180000), message: 'Com limpeza'),
      );

      expect(api.lastBody, {'amount_cents': 180000, 'message': 'Com limpeza'});
      expect(request.quote.amount, Money.fromCents(180000));
      expect(request.partyStatus, PartyStatus.quoted);
    });

    test('o valor sem mensagem não envia a mensagem', () async {
      api.reply('POST', '$_path/$itemId/quote', quoteRequestJson());

      await repository.respond(
        itemId,
        VendorResponse.quote(Money.fromCents(0)),
      );

      expect(api.lastBody, {'amount_cents': 0});
    });

    test('pedir alteração e recusar enviam só o motivo', () async {
      api
        ..reply('POST', '$_path/$itemId/request-changes', quoteRequestJson())
        ..reply('POST', '$_path/$itemId/decline', quoteRequestJson());

      await repository.respond(
        itemId,
        const VendorResponse.requestChanges('Só até 100 pessoas.'),
      );
      expect(api.lastBody, {'message': 'Só até 100 pessoas.'});

      await repository.respond(
        itemId,
        const VendorResponse.decline('Sem agenda neste dia.'),
      );
      expect(api.lastBody, {'message': 'Sem agenda neste dia.'});
      expect(api.calls, [
        'POST $_path/$itemId/request-changes',
        'POST $_path/$itemId/decline',
      ]);
    });

    test('pedido que o cliente já fechou responde com conflito', () async {
      api.fail(
        'POST',
        '$_path/$itemId/quote',
        409,
        'quote_request_closed',
        'Este pedido não está mais aberto para resposta.',
      );

      await expectLater(
        repository.respond(itemId, VendorResponse.quote(Money.fromCents(1))),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'quote_request_closed',
          ),
        ),
      );
    });

    test(
      'o pedido de outro fornecedor não existe para quem pergunta',
      () async {
        api.fail(
          'POST',
          '$_path/$itemId/quote',
          404,
          'quote_request_not_found',
          'Pedido de orçamento não encontrado.',
        );

        await expectLater(
          repository.respond(itemId, VendorResponse.quote(Money.fromCents(1))),
          throwsA(isA<NotFoundFailure>()),
        );
      },
    );
  });

  group('InMemoryQuoteInboxRepository', () {
    late InMemoryPartyRepository parties;
    late InMemoryQuoteInboxRepository inbox;

    /// Grava uma festa com um salão e a taxa obrigatória dele, com o
    /// orçamento solicitado.
    Future<Party> saveRequested({String id = 'party-1'}) {
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
      )..requestQuote();
      return parties.save(
        Party(
          id: PartyId(id),
          ownerId: party.ownerId,
          title: party.title,
          createdAt: party.createdAt,
          updatedAt: party.updatedAt,
          eventType: 'wedding',
          eventDate: party.eventDate,
          guestCount: party.guestCount,
          status: party.status,
          budget: party.budget,
          quoteSnapshot: party.quoteSnapshot,
          quoteRound: party.quoteRound,
          history: party.history,
          clock: fixedClock,
        ),
      );
    }

    setUp(() {
      parties = InMemoryPartyRepository();
      inbox = InMemoryQuoteInboxRepository(parties);
    });

    test('é o que permite responder aos pedidos no modo demonstração', () {
      expect(inbox, isA<QuoteInboxRepository>());
      expect(inbox, isA<DemoVendorAnswers>());
    });

    test(
      'lista um pedido por item, com o evento e sem nada de quem pediu',
      () async {
        await saveRequested();

        final requests = await inbox.list();

        expect(requests.map((request) => request.name), [
          'Salão Glamour',
          'Taxa de limpeza',
        ]);
        final venue = requests.first;
        expect(venue.partyStatus, PartyStatus.locked);
        expect(venue.round, 1);
        expect(venue.eventType, 'wedding');
        expect(venue.eventDate, kEventDay);
        expect(venue.guestCount, 80);
        expect(venue.configuration.durationHours, 4);
        expect(venue.estimate, Money.fromCents(170000));
        expect(venue.quote.status, QuoteStatus.pending);
        expect(requests.last.relation, ItemRelationKind.required);
        expect(requests.last.parentName, 'Salão Glamour');
      },
    );

    test(
      'uma festa em planejamento não aparece para os fornecedores',
      () async {
        await parties.save(planningParty());

        expect(await inbox.list(), isEmpty);
      },
    );

    test('uma festa que voltou para a edição some da lista', () async {
      final party = await saveRequested();
      await parties.save(party..reopenForEditing());

      expect(await inbox.list(), isEmpty);
    });

    test(
      'uma festa cancelada depois do pedido continua na lista, fechada',
      () async {
        final party = await saveRequested();
        await parties.save(party..cancel());

        final requests = await inbox.list();

        expect(requests, hasLength(2));
        expect(requests.first.canRespond, isFalse);
      },
    );

    test('responder grava a resposta na festa, com as regras dela', () async {
      await saveRequested();

      final request = await inbox.respond(
        'venue-1',
        VendorResponse.quote(Money.fromCents(180000), message: 'Com limpeza'),
      );

      expect(request.quote.amount, Money.fromCents(180000));
      expect(request.partyStatus, PartyStatus.locked);
      final saved = (await parties.getById(const PartyId('party-1')))!;
      expect(saved.quotedTotal, Money.fromCents(180000));
      expect(saved.history.last.itemName, 'Salão Glamour');
    });

    test('a última resposta que faltava muda a situação da festa', () async {
      await saveRequested();
      await inbox.respond(
        'venue-1',
        VendorResponse.quote(Money.fromCents(180000)),
      );

      final request = await inbox.respond(
        'service-1',
        VendorResponse.quote(Money.fromCents(15000)),
      );

      expect(request.partyStatus, PartyStatus.quoted);
    });

    test('uma resposta inválida é recusada como a API recusa', () async {
      await saveRequested();

      await expectLater(
        inbox.respond('venue-1', const VendorResponse.decline('não')),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.code,
            'code',
            'invalid_quote_response',
          ),
        ),
      );
      final saved = (await parties.getById(const PartyId('party-1')))!;
      expect(saved.budget.venue!.quote.status, QuoteStatus.pending);
    });

    test('pedido fechado responde com conflito', () async {
      final party = await saveRequested();
      await parties.save(party..cancel());

      await expectLater(
        inbox.respond('venue-1', VendorResponse.quote(Money.fromCents(1))),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'quote_request_closed',
          ),
        ),
      );
    });

    test('pedido que não existe não é encontrado', () async {
      await expectLater(
        inbox.respond('nao-existe', VendorResponse.quote(Money.fromCents(1))),
        throwsA(
          isA<NotFoundFailure>().having(
            (f) => f.code,
            'code',
            'quote_request_not_found',
          ),
        ),
      );
    });
  });
}
