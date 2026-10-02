import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';

import '../party_fixtures.dart';

PartyItemDraft draft({
  String id = 'listing-1',
  String name = 'Salão Glamour',
  int priceCents = 100000,
  PartyItemCategory category = PartyItemCategory.other,
  String? imageUrl = 'https://example.com/foto.jpg',
}) {
  return PartyItemDraft(
    externalRef: ExternalRef(source: 'vendor_catalog', id: id),
    category: category,
    name: name,
    unitPrice: Money.fromCents(priceCents),
    imageUrl: imageUrl,
  );
}

/// Repositório que falha quando mandado, para exercitar os caminhos de erro.
class FlakyPartyRepository implements PartyRepository {
  final InMemoryPartyRepository _inner = InMemoryPartyRepository();

  Object? failOnList;
  Object? failOnSave;

  /// Falha só a partir da enésima gravação (1 = a primeira).
  int failFromSave = 1;
  int saves = 0;

  @override
  Future<List<Party>> listByOwner(String ownerId) async {
    _failWith(failOnList);
    return _inner.listByOwner(ownerId);
  }

  @override
  Future<Party?> getById(PartyId id) => _inner.getById(id);

  @override
  Future<Party> save(Party party) async {
    saves++;
    if (saves >= failFromSave) _failWith(failOnSave);
    return _inner.save(party);
  }

  static void _failWith(Object? failure) {
    if (failure != null) Error.throwWithStackTrace(failure, StackTrace.current);
  }

  @override
  Future<void> deleteById(PartyId id) => _inner.deleteById(id);
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
    );
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
      expect(fresh.budgetItemViews, isEmpty);
      expect(fresh.activePartyTotalCents, 0);
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

    test('trocar de conta descarta as festas da conta anterior', () async {
      await controller.startNewParty('Festa da Ana');
      await repository.save(buildParty(id: 'do-bruno', ownerId: 'user-2'));

      await controller.setOwner('user-2');

      expect(controller.parties.map((p) => p.id.value), ['do-bruno']);
      expect(controller.activePartyId, isNull);
    });

    test('sem dono (visitante) não há festas', () async {
      await controller.startNewParty('Festa da Ana');

      await controller.setOwner(null);

      expect(controller.parties, isEmpty);
      expect(controller.hasLoaded, isTrue);
    });
  });

  group('startNewParty', () {
    test('cria a festa em planejamento e a torna ativa', () async {
      final party = await controller.startNewParty('  15 anos da Maria ');

      expect(party!.title.value, '15 anos da Maria');
      expect(party.status, PartyStatus.planning);
      expect(party.ownerId, 'user-1');
      expect(controller.activeParty, same(party));
      expect(controller.parties, [party]);
      expect(await repository.getById(party.id), same(party));
    });

    test('título vazio falha com mensagem e não cria nada', () async {
      final party = await controller.startNewParty('   ');

      expect(party, isNull);
      expect(controller.error, 'Título não pode ser vazio.');
      expect(controller.parties, isEmpty);
      expect(controller.isBusy, isFalse);
    });

    test('visitante não cria festa', () async {
      await controller.setOwner(null);

      expect(await controller.startNewParty('Festa'), isNull);
      expect(controller.error, 'Entre na sua conta para criar festas.');
    });
  });

  group('addItemToParty', () {
    test('adiciona o item com nome, preço, categoria e imagem', () async {
      final party = (await controller.startNewParty('Casamento'))!;

      final added = await controller.addItemToParty(
        party.id,
        draft(category: PartyItemCategory.venue),
      );

      expect(added, isTrue);
      final view = controller.budgetItemViews.single;
      expect(view.name, 'Salão Glamour');
      expect(view.unitPriceCents, 100000);
      expect(view.quantity, 1);
      expect(view.category, 'venue');
      expect(view.imageUrl, 'https://example.com/foto.jpg');
      expect(controller.activePartyTotalCents, 100000);
    });

    test('adicionar o mesmo anúncio de novo soma a quantidade', () async {
      final party = (await controller.startNewParty('Casamento'))!;

      await controller.addItemToParty(party.id, draft());
      await controller.addItemToParty(party.id, draft());

      expect(controller.budgetItemViews.single.quantity, 2);
      expect(controller.activePartyTotalCents, 200000);
    });

    test('recusa festa travada com a mensagem da regra', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      await controller.addItemToParty(party.id, draft());
      await controller.lockActivePartyForPayment();

      final added = await controller.addItemToParty(
        party.id,
        draft(id: 'listing-2', name: 'Buffet'),
      );

      expect(added, isFalse);
      expect(
        controller.error,
        'Só é possível adicionar itens em draft/planning.',
      );
      expect(controller.budgetItemViews, hasLength(1));
    });

    test('segundo salão é recusado', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      await controller.addItemToParty(
        party.id,
        draft(category: PartyItemCategory.venue),
      );

      final added = await controller.addItemToParty(
        party.id,
        draft(id: 'listing-2', category: PartyItemCategory.venue),
      );

      expect(added, isFalse);
      expect(controller.error, contains('Salão'));
    });

    test('festa inexistente falha com mensagem', () async {
      final added = await controller.addItemToParty(
        const PartyId('nao-existe'),
        draft(),
      );

      expect(added, isFalse);
      expect(controller.error, 'Festa não encontrada.');
    });
  });

  group('addItemToNewParty', () {
    test('cria a festa já com o item e a torna ativa', () async {
      final added = await controller.addItemToNewParty('Chá de bebê', draft());

      expect(added, isTrue);
      expect(controller.activeParty!.title.value, 'Chá de bebê');
      expect(controller.budgetItemViews.single.name, 'Salão Glamour');
    });

    test('se o item não entra, a festa recém-criada é descartada', () async {
      final flaky = FlakyPartyRepository()
        ..failOnSave = const NetworkFailure()
        ..failFromSave = 2; // a criação grava; a inclusão do item falha
      final failing = build(flaky);
      addTearDown(failing.dispose);
      await failing.load();

      final added = await failing.addItemToNewParty('Chá de bebê', draft());

      expect(added, isFalse);
      expect(failing.error, const NetworkFailure().message);
      expect(failing.parties, isEmpty);
      expect(await flaky.listByOwner('user-1'), isEmpty);
    });
  });

  group('remoção de itens', () {
    test('remove um item e mantém a festa quando sobram outros', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      await controller.addItemToParty(party.id, draft(name: 'Salão'));
      await controller.addItemToParty(
        party.id,
        draft(id: 'listing-2', name: 'DJ'),
      );
      final salao = controller.budgetItemViews.firstWhere(
        (v) => v.name == 'Salão',
      );

      final removed = await controller.removeItemFromActiveParty(salao.id);

      expect(removed, isTrue);
      expect(controller.budgetItemViews.single.name, 'DJ');
      expect(controller.activeParty, isNotNull);
    });

    test('itens criados em sequência imediata têm ids diferentes', () async {
      // Regressão: os ids vinham do relógio e colidiam no mesmo instante;
      // remover um item apagava os dois.
      final party = (await controller.startNewParty('Casamento'))!;
      await Future.wait([
        for (var i = 0; i < 20; i++)
          controller.addItemToParty(
            party.id,
            draft(id: 'listing-$i', name: 'Item $i'),
          ),
      ]);

      final ids = controller.budgetItemViews.map((v) => v.id).toSet();

      expect(ids, hasLength(20));
    });

    test('remover o último item apaga a festa e encerra a sessão', () async {
      // Regressão: a remoção era reportada como falha e a festa apagada
      // continuava na lista.
      final party = (await controller.startNewParty('Casamento'))!;
      await controller.addItemToParty(party.id, draft());
      final itemId = controller.budgetItemViews.single.id;

      final removed = await controller.removeItemFromActiveParty(itemId);

      expect(removed, isTrue);
      expect(controller.error, isNull);
      expect(controller.activeParty, isNull);
      expect(controller.parties, isEmpty);
      expect(await repository.getById(party.id), isNull);
    });

    test('item desconhecido falha com mensagem', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      await controller.addItemToParty(party.id, draft());

      expect(await controller.removeItemFromActiveParty('nao-existe'), isFalse);
      expect(controller.error, 'Item não encontrado na Party.');
    });

    test('sem festa ativa, falha com mensagem', () async {
      expect(await controller.removeItemFromActiveParty('x'), isFalse);
      expect(controller.error, 'Nenhuma festa selecionada.');
    });
  });

  group('travar e destravar', () {
    test('trava a festa ativa e depois destrava', () async {
      await controller.addItemToNewParty('Casamento', draft());

      expect(await controller.lockActivePartyForPayment(), isTrue);
      expect(controller.isActivePartyLocked, isTrue);
      expect(controller.activeParty!.paymentSnapshot, isNotNull);
      expect(controller.editableParties, isEmpty);

      expect(await controller.unlockActiveParty(), isTrue);
      expect(controller.isActivePartyLocked, isFalse);
      expect(controller.editableParties, hasLength(1));
    });

    test('festa sem itens não pode ser travada', () async {
      await controller.startNewParty('Casamento');

      expect(await controller.lockActivePartyForPayment(), isFalse);
      expect(controller.error, contains('sem itens'));
    });

    test('sem festa ativa, falha com mensagem', () async {
      expect(await controller.lockActivePartyForPayment(), isFalse);
      expect(controller.error, 'Nenhuma festa selecionada.');
    });
  });

  group('sessão ativa', () {
    test('clearActiveParty volta ao hub sem apagar a festa', () async {
      await controller.addItemToNewParty('Casamento', draft());

      controller.clearActiveParty();

      expect(controller.activeParty, isNull);
      expect(controller.parties, hasLength(1));
    });

    test('setActiveParty seleciona uma festa existente', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      controller.clearActiveParty();

      controller.setActiveParty(party.id);

      expect(controller.activeParty, same(party));
    });

    test('recarregar encerra a sessão se a festa não existe mais', () async {
      final party = (await controller.startNewParty('Casamento'))!;
      await repository.deleteById(party.id);

      await controller.load();

      expect(controller.activePartyId, isNull);
      expect(controller.parties, isEmpty);
    });
  });

  group('isInAnyParty', () {
    test('acusa itens que estão em qualquer festa em andamento', () async {
      await controller.addItemToNewParty('Casamento', draft(id: 'salao-1'));
      controller.clearActiveParty();

      expect(controller.isInAnyParty('salao-1'), isTrue);
      expect(controller.isInAnyParty('outro'), isFalse);
    });
  });

  group('falhas do repositório', () {
    test('erro de rede vira mensagem e não altera o estado', () async {
      final flaky = FlakyPartyRepository();
      final failing = build(flaky);
      addTearDown(failing.dispose);
      await failing.load();
      final party = (await failing.startNewParty('Casamento'))!;
      flaky.failOnSave = const NetworkFailure();

      final added = await failing.addItemToParty(party.id, draft());

      expect(added, isFalse);
      expect(failing.error, const NetworkFailure().message);
      expect(failing.isBusy, isFalse);
    });

    test('conflito de versão recarrega as festas do servidor', () async {
      final flaky = FlakyPartyRepository();
      final failing = build(flaky);
      addTearDown(failing.dispose);
      await failing.load();
      final party = (await failing.startNewParty('Casamento'))!;
      // Outro dispositivo criou mais uma festa e alterou esta.
      await flaky.save(buildParty(id: 'do-tablet', ownerId: 'user-1'));
      flaky
        ..failOnSave = const ConflictFailure(
          'A festa foi alterada em outro dispositivo.',
          'party_version_conflict',
        )
        ..failFromSave = 1;

      final added = await failing.addItemToParty(party.id, draft());

      expect(added, isFalse);
      expect(failing.error, 'A festa foi alterada em outro dispositivo.');
      expect(
        failing.parties.map((p) => p.id.value),
        containsAll(['do-tablet', party.id.value]),
      );
    });

    test('erro inesperado nunca mostra detalhe técnico', () async {
      final flaky = FlakyPartyRepository()..failOnSave = StateError('npe');
      final failing = build(flaky);
      addTearDown(failing.dispose);
      await failing.load();

      await failing.startNewParty('Casamento');

      expect(failing.error, const UnexpectedFailure().message);
    });
  });

  group('notificações', () {
    test('sinaliza ocupado durante a operação e avisa os ouvintes', () async {
      final busyStates = <bool>[];
      controller.addListener(() => busyStates.add(controller.isBusy));

      await controller.startNewParty('Casamento');

      expect(busyStates.first, isTrue);
      expect(busyStates.last, isFalse);
    });

    test('operação que termina depois do dispose não quebra', () async {
      final disposable = build(repository);
      await disposable.load();

      final pending = disposable.startNewParty('Casamento');
      disposable.dispose();

      await expectLater(pending, completes);
    });
  });
}
