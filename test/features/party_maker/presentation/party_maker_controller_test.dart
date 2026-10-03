import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';

import '../party_fixtures.dart';

/// Repositório que falha quando mandado, para exercitar os caminhos de erro.
class FlakyPartyRepository implements PartyRepository {
  final InMemoryPartyRepository inner = InMemoryPartyRepository();

  Object? failOnList;
  Object? failOnSave;
  Object? failOnDelete;

  /// Falha só a partir da enésima gravação (1 = a primeira).
  int failFromSave = 1;
  int saves = 0;

  /// Segura a próxima listagem até o teste liberar.
  Completer<void>? holdList;

  @override
  Future<List<Party>> listByOwner(String ownerId) async {
    await holdList?.future;
    _failWith(failOnList);
    return inner.listByOwner(ownerId);
  }

  @override
  Future<Party?> getById(PartyId id) => inner.getById(id);

  @override
  Future<Party> save(Party party) async {
    saves++;
    if (saves >= failFromSave) _failWith(failOnSave);
    return inner.save(party);
  }

  @override
  Future<void> deleteById(PartyId id) async {
    _failWith(failOnDelete);
    return inner.deleteById(id);
  }

  static void _failWith(Object? failure) {
    if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
  }
}

/// Um salão do catálogo com uma taxa obrigatória, já configurado.
ConfiguredItem venueSelection() {
  final cleaning = buildDraft(
    ref: const ExternalRef.offer('offer-cleaning'),
    name: 'Taxa de limpeza',
    priceCents: 15000,
    isRequired: true,
  );
  return buildSelection(
    draft: buildDraft(
      externalId: 'listing-venue',
      category: PartyItemCategory.venue,
      name: 'Salão Glamour',
      priceCents: 170000,
      capacity: 120,
      ownServices: [cleaning],
    ),
    configuration: kFourHours,
    ownServices: [buildSelection(draft: cleaning)],
  );
}

void main() {
  late InMemoryPartyRepository repository;
  late PartyMakerController controller;

  PartyMakerController build(
    PartyRepository repo, {
    String? ownerId = 'user-1',
  }) {
    return PartyMakerController(
      repository: repo,
      ids: UuidGenerator(),
      ownerId: ownerId,
      clock: fixedClock,
    );
  }

  /// Cria uma festa com data e convidados, pronta para receber itens.
  Future<Party> createParty([PartyMakerController? target]) async {
    final party = await (target ?? controller).createParty(
      buildDetails(eventDate: kEventDay, guests: 80),
    );
    return party!;
  }

  /// O fornecedor responde a todos os itens: o que o modo demonstração faz.
  Future<void> vendorQuotes(PartyId id, int cents) async {
    final party = (await repository.getById(id))!;
    for (final item in party.budget.items) {
      party.registerVendorResponse(
        item.id,
        VendorResponse.quote(Money.fromCents(cents)),
      );
    }
    await repository.save(party);
  }

  setUp(() async {
    repository = InMemoryPartyRepository();
    controller = build(repository);
    await controller.load();
  });

  tearDown(() => controller.dispose());

  group('carga', () {
    test('antes de carregar, o estado é vazio e não carregado', () {
      final fresh = build(repository);
      addTearDown(fresh.dispose);

      expect(fresh.hasLoaded, isFalse);
      expect(fresh.parties, isEmpty);
      expect(fresh.activeParty, isNull);
      expect(fresh.editableParties, isEmpty);
      expect(fresh.isBusy, isFalse);
      expect(fresh.error, isNull);
    });

    test(
      'traz só as festas do dono, da mais recente para a mais antiga',
      () async {
        await repository.save(buildParty(id: 'antiga', ownerId: 'user-1'));
        await repository.save(
          buildParty(id: 'recente', ownerId: 'user-1')..startPlanning(),
        );
        await repository.save(
          buildParty(id: 'alheia', ownerId: 'outra-pessoa'),
        );

        await controller.load();

        expect(controller.hasLoaded, isTrue);
        expect(controller.parties.map((p) => p.id.value), [
          'recente',
          'antiga',
        ]);
      },
    );

    test('falha na carga fica em loadError e pode ser repetida', () async {
      final flaky = FlakyPartyRepository()..failOnList = const NetworkFailure();
      final failing = build(flaky);
      addTearDown(failing.dispose);

      await failing.load();
      expect(failing.hasLoaded, isTrue);
      expect(failing.loadError, const NetworkFailure().message);
      expect(failing.error, isNull);

      flaky.failOnList = null;
      await failing.load();
      expect(failing.loadError, isNull);
    });

    test('uma atualização que falha mantém as festas que já estavam na '
        'tela', () async {
      final flaky = FlakyPartyRepository();
      final target = build(flaky);
      addTearDown(target.dispose);
      await target.load();
      await createParty(target);

      flaky.failOnList = const NetworkFailure();
      await target.load();

      expect(target.parties, hasLength(1));
      expect(target.loadError, isNotNull);
    });

    test('sem conta, não há festas e nada é buscado', () async {
      final visitor = build(repository, ownerId: null);
      addTearDown(visitor.dispose);

      await visitor.load();

      expect(visitor.hasLoaded, isTrue);
      expect(visitor.parties, isEmpty);
    });

    test('recarregar traz o que mudou do outro lado: a resposta de um '
        'fornecedor', () async {
      final party = await createParty();
      await controller.addItem(party.id, buildSelection());
      await controller.requestQuote(party.id);

      await vendorQuotes(party.id, 90000);
      expect(controller.activeParty!.status, PartyStatus.locked);

      await controller.load();

      expect(controller.activeParty!.status, PartyStatus.quoted);
      expect(controller.activeParty!.quotedTotal, Money.fromCents(90000));
    });

    test('se a festa aberta sumiu, a aba volta para a lista', () async {
      final party = await createParty();
      expect(controller.activePartyId, party.id);

      await repository.deleteById(party.id);
      await controller.load();

      expect(controller.activePartyId, isNull);
    });
  });

  group('troca de conta', () {
    test('descarta as festas da conta anterior e carrega as da nova', () async {
      await createParty();
      await repository.save(buildParty(id: 'da-outra', ownerId: 'user-2'));

      await controller.setOwner('user-2');

      expect(controller.parties.map((p) => p.id.value), ['da-outra']);
      expect(controller.activePartyId, isNull);
    });

    test('ao sair da conta, não sobra nenhuma festa na tela', () async {
      await createParty();

      await controller.setOwner(null);

      expect(controller.parties, isEmpty);
      expect(controller.activeParty, isNull);
    });

    test('a resposta de uma conta que já saiu é descartada', () async {
      final flaky = FlakyPartyRepository();
      await flaky.inner.save(buildParty(id: 'da-primeira', ownerId: 'user-1'));
      final target = build(flaky);
      addTearDown(target.dispose);

      // A busca da primeira conta fica presa enquanto a pessoa troca de conta.
      flaky.holdList = Completer<void>();
      final first = target.load();
      final hold = flaky.holdList!;
      flaky.holdList = null;
      final second = target.setOwner('user-2');
      hold.complete();
      await Future.wait([first, second]);

      expect(target.parties, isEmpty);
    });

    test('depois de descartado, o controller não avisa mais ninguém', () async {
      final target = build(repository);
      var notifications = 0;
      target.addListener(() => notifications++);

      final loading = target.load();
      target.dispose();
      await loading;

      expect(notifications, 0);
    });
  });

  group('criar a festa', () {
    test(
      'cria em planejamento, com os dados do evento, e abre na aba',
      () async {
        final party = await controller.createParty(
          buildDetails(
            title: 'Casamento',
            eventType: 'wedding',
            eventDate: kEventDay,
            guests: 150,
          ),
        );

        expect(party!.status, PartyStatus.planning);
        expect(party.eventType, 'wedding');
        expect(controller.activePartyId, party.id);
        expect(controller.parties.single.title.value, 'Casamento');
        expect((await repository.getById(party.id))!.guestCount!.value, 150);
      },
    );

    test('a festa pode nascer só com o nome', () async {
      final party = await controller.createParty(
        buildDetails(title: 'Churrasco'),
      );

      expect(party!.eventDate, isNull);
      expect(party.budget.isEmpty, isTrue);
    });

    test('sem conta, não cria e explica', () async {
      final visitor = build(repository, ownerId: null);
      addTearDown(visitor.dispose);

      expect(await visitor.createParty(buildDetails()), isNull);
      expect(visitor.error, 'Entre na sua conta para criar festas.');
    });

    test('a regra que barra a criação vira a mensagem da tela', () async {
      final party = await controller.createParty(
        buildDetails(eventDate: kFixedNow.subtract(const Duration(days: 1))),
      );

      expect(party, isNull);
      expect(controller.error, const EventDateInPast().message);
      expect(controller.parties, isEmpty);
    });
  });

  group('itens', () {
    test('põe um item configurado na festa', () async {
      final party = await createParty();

      final saved = await controller.addItem(
        party.id,
        buildSelection(quantity: 3),
      );

      expect(saved!.budget.items.single.quantity.value, 3);
      expect(controller.activeParty!.budget.items, hasLength(1));
      expect(controller.isInAnyParty('listing-1'), isTrue);
      expect(controller.isInAnyParty('outro'), isFalse);
    });

    test('o salão entra com o serviço obrigatório dele', () async {
      final party = await createParty();

      final saved = await controller.addItem(party.id, venueSelection());

      expect(saved!.budget.items.map((item) => item.nameSnapshot), [
        'Salão Glamour',
        'Taxa de limpeza',
      ]);
      expect(saved.estimate.total, Money.fromCents(185000));
    });

    test('cria a festa já com o item, e ela fica aberta', () async {
      final saved = await controller.addItemToNewParty(
        buildDetails(title: 'Festa nova', eventDate: kEventDay, guests: 80),
        venueSelection(),
      );

      expect(saved!.title.value, 'Festa nova');
      expect(controller.activePartyId, saved.id);
      expect(controller.parties, hasLength(1));
    });

    test(
      'se o primeiro item não pode entrar, nenhuma festa é criada',
      () async {
        final saved = await controller.addItemToNewParty(
          // Sem a data e os convidados, o salão não entra.
          buildDetails(title: 'Festa nova'),
          venueSelection(),
        );

        expect(saved, isNull);
        expect(controller.error, const EventDetailsRequired().message);
        expect(controller.parties, isEmpty);
        expect(await repository.listByOwner('user-1'), isEmpty);
      },
    );

    test('a regra que barra um item vira a mensagem da tela', () async {
      final party = await createParty();
      await controller.addItem(party.id, buildSelection());

      final again = await controller.addItem(party.id, buildSelection());

      expect(again, isNull);
      expect(controller.error, const DuplicatePartyItem().message);
      expect(controller.activeParty!.budget.items, hasLength(1));
    });

    test('altera a configuração de um item', () async {
      final party = await createParty();
      final added = await controller.addItem(party.id, buildSelection());
      final itemId = added!.budget.items.single.id;

      final changed = await controller.updateItem(
        party.id,
        itemId,
        quantity: 5,
        configuration: const {'variation': 'Azul'},
      );

      expect(changed, isTrue);
      final item = controller.activeParty!.budget.items.single;
      expect(item.quantity.value, 5);
      expect(item.configuration['variation'], 'Azul');
    });

    test('remove um item e conta o que saiu junto', () async {
      final party = await createParty();
      final added = await controller.addItem(party.id, venueSelection());

      final removal = await controller.removeItem(
        party.id,
        added!.budget.venue!.id,
      );

      expect(removal!.removedWith.single.nameSnapshot, 'Taxa de limpeza');
      // A festa continua existindo, vazia.
      expect(controller.activeParty!.budget.isEmpty, isTrue);
      expect(controller.parties, hasLength(1));
    });

    test('tentar tirar um serviço obrigatório explica por quê', () async {
      final party = await createParty();
      final added = await controller.addItem(party.id, venueSelection());

      final removal = await controller.removeItem(
        party.id,
        added!.budget.items.last.id,
      );

      expect(removal, isNull);
      expect(controller.error, contains('Taxa de limpeza é obrigatório'));
      expect(controller.activeParty!.budget.items, hasLength(2));
    });

    test('troca os dados do evento', () async {
      final party = await createParty();

      final changed = await controller.updateEventDetails(
        party.id,
        buildDetails(title: 'Outro nome', eventDate: kEventDay, guests: 60),
      );

      expect(changed, isTrue);
      expect(controller.activeParty!.title.value, 'Outro nome');
      expect(controller.activeParty!.guestCount!.value, 60);
    });
  });

  group('o orçamento', () {
    late PartyId partyId;

    setUp(() async {
      final party = await createParty();
      partyId = party.id;
      await controller.addItem(partyId, buildSelection());
    });

    test('solicita, e a festa deixa de aceitar itens', () async {
      expect(await controller.requestQuote(partyId), isTrue);

      final party = controller.activeParty!;
      expect(party.status, PartyStatus.locked);
      expect(party.budget.items.single.quote.status, QuoteStatus.pending);
      expect(controller.editableParties, isEmpty);

      final added = await controller.addItem(
        partyId,
        buildSelection(draft: buildDraft(externalId: 'listing-2')),
      );
      expect(added, isNull);
      expect(controller.error, const PartyLockedMutationNotAllowed().message);
    });

    test('a pendência que barra o pedido vira a mensagem da tela', () async {
      final other = await controller.createParty(buildDetails(title: 'Vazia'));

      expect(await controller.requestQuote(other!.id), isFalse);
      expect(controller.error, const CannotLockWithoutItems().message);
    });

    test('volta a editar, altera e pede de novo', () async {
      await controller.requestQuote(partyId);
      await vendorQuotes(partyId, 90000);
      await controller.load();

      expect(await controller.reopen(partyId), isTrue);
      expect(controller.activeParty!.status, PartyStatus.planning);
      // O valor que o fornecedor deu continua à vista.
      expect(controller.activeParty!.quotedTotal, Money.fromCents(90000));

      final itemId = controller.activeParty!.budget.items.single.id;
      await controller.updateItem(
        partyId,
        itemId,
        quantity: 2,
        configuration: const {},
      );
      expect(controller.activeParty!.quotedTotal, isNull);

      expect(await controller.requestQuote(partyId), isTrue);
      expect(controller.activeParty!.quoteRound, 2);
    });

    test('aceita o orçamento recebido', () async {
      await controller.requestQuote(partyId);
      expect(await controller.confirmQuote(partyId), isFalse);

      await vendorQuotes(partyId, 90000);
      await controller.load();

      expect(await controller.confirmQuote(partyId), isTrue);
      expect(controller.activeParty!.status, PartyStatus.confirmed);
    });

    test('cancela a festa', () async {
      await controller.requestQuote(partyId);

      expect(await controller.cancelParty(partyId), isTrue);
      expect(controller.activeParty!.status, PartyStatus.cancelled);
      // Uma festa cancelada não conta como "em alguma festa".
      expect(controller.isInAnyParty('listing-1'), isFalse);
    });

    test('apaga a festa e volta para a lista', () async {
      expect(await controller.deleteParty(partyId), isTrue);

      expect(controller.parties, isEmpty);
      expect(controller.activePartyId, isNull);
      expect(await repository.getById(partyId), isNull);
    });

    test(
      'com o orçamento solicitado, apagar pede o cancelamento antes',
      () async {
        await controller.requestQuote(partyId);

        expect(await controller.deleteParty(partyId), isFalse);
        expect(controller.error, const PartyHasOpenQuote().message);
        expect(controller.parties, hasLength(1));
      },
    );
  });

  group('navegação entre a lista e a festa', () {
    test('abre e fecha uma festa', () async {
      final party = await createParty();

      controller.clearActiveParty();
      expect(controller.activeParty, isNull);

      controller.setActiveParty(party.id);
      expect(controller.activeParty!.id, party.id);
      expect(controller.partyById(const PartyId('nao-existe')), isNull);
    });

    test('fechar sem nada aberto não avisa ninguém', () {
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.clearActiveParty();

      expect(notifications, 0);
    });
  });

  group('falhas ao gravar', () {
    late FlakyPartyRepository flaky;
    late PartyMakerController target;

    setUp(() async {
      flaky = FlakyPartyRepository();
      target = build(flaky);
      await target.load();
    });

    tearDown(() => target.dispose());

    test('a falha vira mensagem, e a festa fica como estava', () async {
      final party = await createParty(target);
      flaky
        ..failOnSave = const NetworkFailure()
        ..failFromSave = 0;

      final saved = await target.addItem(party.id, buildSelection());

      expect(saved, isNull);
      expect(target.error, const NetworkFailure().message);
      expect(target.isBusy, isFalse);
      expect(target.activeParty!.budget.isEmpty, isTrue);
    });

    test(
      'um conflito recarrega as festas: outro lado gravou primeiro',
      () async {
        final party = await createParty(target);
        // Outro aparelho (ou um fornecedor respondendo) mudou a festa.
        final elsewhere = (await flaky.inner.getById(party.id))!
          ..updateEventDetails(
            buildDetails(title: 'Do tablet', eventDate: kEventDay, guests: 80),
          );
        await flaky.inner.save(elsewhere);
        flaky
          ..failOnSave = const ConflictFailure(
            'A festa mudou em outro aparelho. Atualizamos os dados.',
            'party_version_conflict',
          )
          ..failFromSave = 0;

        final saved = await target.addItem(party.id, buildSelection());

        expect(saved, isNull);
        expect(target.error, contains('mudou em outro aparelho'));
        // A tela volta a mostrar o que está gravado.
        expect(target.activeParty!.title.value, 'Do tablet');
      },
    );

    test('uma operação seguinte limpa a mensagem da anterior', () async {
      final party = await createParty(target);
      flaky
        ..failOnSave = const NetworkFailure()
        ..failFromSave = 0;
      await target.addItem(party.id, buildSelection());
      expect(target.error, isNotNull);

      flaky.failOnSave = null;
      await target.addItem(party.id, buildSelection());

      expect(target.error, isNull);
    });

    test('falha ao apagar deixa a festa na lista', () async {
      final party = await createParty(target);
      flaky.failOnDelete = const NetworkFailure();

      expect(await target.deleteParty(party.id), isFalse);
      expect(target.parties, hasLength(1));
      expect(target.error, const NetworkFailure().message);
    });

    test(
      'um erro que não é uma falha conhecida vira a mensagem genérica',
      () async {
        final party = await createParty(target);
        flaky
          ..failOnSave = StateError('algo inesperado')
          ..failFromSave = 0;

        await target.addItem(party.id, buildSelection());

        expect(target.error, const UnexpectedFailure().message);
      },
    );

    test(
      'fica ocupado enquanto grava e avisa a tela nas duas pontas',
      () async {
        final party = await createParty(target);
        final busy = <bool>[];
        target.addListener(() => busy.add(target.isBusy));

        await target.addItem(party.id, buildSelection());

        expect(busy.first, isTrue);
        expect(busy.last, isFalse);
      },
    );

    test('uma operação espera a carga em andamento terminar', () async {
      final party = await createParty(target);
      flaky.holdList = Completer<void>();
      final loading = target.load();

      final adding = target.addItem(party.id, buildSelection());
      flaky.holdList!.complete();
      await loading;
      final saved = await adding;

      // A carga não passou por cima do que a operação gravou.
      expect(saved!.budget.items, hasLength(1));
      expect(target.activeParty!.budget.items, hasLength(1));
    });
  });

  group('um item cobrado por pessoa', () {
    test('pede o número de convidados, que vai junto no mesmo passo', () async {
      final party = await controller.createParty(
        buildDetails(title: 'Sem lista'),
      );
      final buffet = buildSelection(
        draft: buildDraft(
          externalId: 'listing-buffet',
          category: PartyItemCategory.buffet,
          name: 'Buffet Sabor',
          model: PricingModel.perPerson,
          priceCents: 5500,
        ),
        configuration: const {'service_style': 'plated'},
      );

      expect(await controller.addItem(party!.id, buffet), isNull);
      expect(controller.error, const GuestCountRequired().message);

      final saved = await controller.addItem(
        party.id,
        buffet,
        eventDetails: buildDetails(title: 'Sem lista', guests: 50),
      );

      expect(saved!.guestCount!.value, 50);
      expect(saved.estimate.total, Money.fromCents(275000));
    });
  });
}
