import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/quote_inbox_controller.dart';

import '../party_fixtures.dart';

/// Caixa de pedidos que falha quando mandada.
class FlakyQuoteInbox implements QuoteInboxRepository {
  FlakyQuoteInbox(this._inner);

  final QuoteInboxRepository _inner;
  Object? failOnList;
  Object? failOnRespond;
  int lists = 0;

  @override
  Future<List<QuoteRequest>> list() async {
    lists++;
    final failure = failOnList;
    if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
    return _inner.list();
  }

  @override
  Future<QuoteRequest> respond(String itemId, VendorResponse response) async {
    final failure = failOnRespond;
    if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
    return _inner.respond(itemId, response);
  }
}

void main() {
  late InMemoryPartyRepository parties;
  late FlakyQuoteInbox inbox;
  late QuoteInboxController controller;

  List<QuoteRequest> requests() => controller.state.valueOrNull!;

  VendorResponse quoteOf(int cents) =>
      VendorResponse.quote(Money.fromCents(cents));

  setUp(() async {
    parties = InMemoryPartyRepository();
    inbox = FlakyQuoteInbox(InMemoryQuoteInboxRepository(parties));
    controller = QuoteInboxController(inbox);

    // Uma festa com dois itens e o orçamento solicitado.
    await parties.save(
      planningParty(
        items: [
          buildItem(),
          buildItem(id: 'item-2', externalId: 'listing-2', name: 'Bolo'),
        ],
      )..requestQuote(),
    );
  });

  tearDown(() => controller.dispose());

  test('começa carregando, e a carga traz os pedidos', () async {
    expect(controller.state.isLoading, isTrue);

    await controller.load();

    expect(requests().map((request) => request.name), ['Kit de copos', 'Bolo']);
    expect(controller.isBusy, isFalse);
    expect(controller.error, isNull);
  });

  test('a falha na carga fica no estado, e dá para tentar de novo', () async {
    inbox.failOnList = const NetworkFailure();

    await controller.load();
    expect(controller.state, isA<LoadFailure<List<QuoteRequest>>>());

    inbox.failOnList = null;
    await controller.load();
    expect(requests(), hasLength(2));
  });

  test('um erro que não é uma falha conhecida vira a falha genérica', () async {
    inbox.failOnList = StateError('algo inesperado');

    await controller.load();

    final state = controller.state as LoadFailure<List<QuoteRequest>>;
    expect(state.failure, isA<UnexpectedFailure>());
  });

  test('atualizar não tira a lista da tela enquanto busca', () async {
    await controller.load();
    final states = <LoadState<List<QuoteRequest>>>[];
    controller.addListener(() => states.add(controller.state));

    await controller.load();

    expect(states, everyElement(isA<LoadSuccess<List<QuoteRequest>>>()));
  });

  test('responder envia a resposta e busca a lista de novo', () async {
    await controller.load();

    final sent = await controller.respond('item-1', quoteOf(90000));

    expect(sent, isTrue);
    expect(requests().first.quote.amount, Money.fromCents(90000));
    expect(requests().first.quote.status, QuoteStatus.quoted);
    expect(inbox.lists, 2);
  });

  test('a última resposta muda a situação de todos os pedidos do '
      'evento', () async {
    await controller.load();
    await controller.respond('item-1', quoteOf(90000));

    await controller.respond('item-2', quoteOf(10000));

    // Os dois pedidos são da mesma festa: a lista inteira foi buscada de novo.
    expect(
      requests().map((request) => request.partyStatus),
      everyElement(PartyStatus.quoted),
    );
  });

  test(
    'uma resposta recusada vira mensagem, e a lista fica como está',
    () async {
      await controller.load();

      final sent = await controller.respond(
        'item-1',
        const VendorResponse.decline('não'),
      );

      expect(sent, isFalse);
      expect(controller.error, 'Explique o motivo para o cliente.');
      expect(requests().first.quote.status, QuoteStatus.pending);
      expect(controller.isBusy, isFalse);
    },
  );

  test('se o cliente fechou o pedido, a lista é buscada de novo', () async {
    await controller.load();
    // Enquanto o fornecedor escrevia, o cliente cancelou a festa.
    final party = (await parties.getById(const PartyId('party-1')))!..cancel();
    await parties.save(party);

    final sent = await controller.respond('item-1', quoteOf(90000));

    expect(sent, isFalse);
    expect(controller.error, isNotNull);
    expect(requests().first.canRespond, isFalse);
  });

  test('falha de rede ao responder não mexe na lista', () async {
    await controller.load();
    inbox.failOnRespond = const NetworkFailure();

    final sent = await controller.respond('item-1', quoteOf(90000));

    expect(sent, isFalse);
    expect(controller.error, const NetworkFailure().message);
    expect(inbox.lists, 1);
  });

  test('fica ocupado enquanto envia e avisa a tela nas duas pontas', () async {
    await controller.load();
    final busy = <bool>[];
    controller.addListener(() => busy.add(controller.isBusy));

    await controller.respond('item-1', quoteOf(90000));

    expect(busy.first, isTrue);
    expect(busy.last, isFalse);
  });

  test('depois de descartado, não avisa mais ninguém', () async {
    final target = QuoteInboxController(inbox);
    var notifications = 0;
    target.addListener(() => notifications++);

    final loading = target.load();
    target.dispose();
    await loading;

    expect(notifications, 0);
  });
}
