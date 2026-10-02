import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/add_item_to_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/cancel_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/create_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/lock_party_for_payment_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/remove_item_from_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/rename_party_title_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/start_planning_use_case.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/unlock_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

void main() {
  const partyId = PartyId('party-1');
  const missingId = PartyId('nao-existe');

  late InMemoryPartyRepository repository;

  Matcher throwsPartyNotFound() => throwsA(
        isA<PartyDomainException>()
            .having((e) => e.code, 'code', 'party_not_found'),
      );

  Future<void> createPlanningParty() async {
    await CreatePartyUseCase(repository)(
      partyId: partyId,
      ownerId: 'user-1',
      title: PartyTitle('Aniversário da Ana'),
    );
    await StartPlanningUseCase(repository)(partyId);
  }

  Future<void> addItem({
    String itemId = 'item-1',
    String externalId = 'listing-1',
    PartyItemCategory category = PartyItemCategory.other,
  }) {
    return AddItemToPartyUseCase(repository)(
      partyId: partyId,
      partyItemId: PartyItemId(itemId),
      externalRef: ExternalRef(source: 'vendor_catalog', id: externalId),
      category: category,
      nameSnapshot: 'DJ Festa Boa',
      unitPriceSnapshot: Money.fromCents(80000),
      quantity: Quantity(1),
    );
  }

  setUp(() => repository = InMemoryPartyRepository());

  group('CreatePartyUseCase', () {
    test('persiste a festa como rascunho', () async {
      final party = await CreatePartyUseCase(repository)(
        partyId: partyId,
        ownerId: 'user-1',
        title: PartyTitle('Aniversário da Ana'),
      );

      final stored = await repository.getById(partyId);
      expect(stored, same(party));
      expect(stored!.status, PartyStatus.draft);
      expect(stored.ownerId, 'user-1');
    });
  });

  group('StartPlanningUseCase', () {
    test('move a festa para planejamento', () async {
      await createPlanningParty();

      expect((await repository.getById(partyId))!.status, PartyStatus.planning);
    });

    test('falha para festa inexistente', () {
      expect(StartPlanningUseCase(repository)(missingId), throwsPartyNotFound());
    });
  });

  group('AddItemToPartyUseCase', () {
    test('adiciona o item e persiste', () async {
      await createPlanningParty();

      await addItem();

      final stored = (await repository.getById(partyId))!;
      expect(stored.budget.items, hasLength(1));
      expect(stored.budget.total, Money.fromCents(80000));
    });

    test('propaga as regras do domínio', () async {
      await createPlanningParty();
      await addItem(category: PartyItemCategory.venue);

      expect(
        addItem(
          itemId: 'item-2',
          externalId: 'listing-2',
          category: PartyItemCategory.venue,
        ),
        throwsA(isA<VenueAlreadySelected>()),
      );
    });

    test('falha para festa inexistente', () {
      expect(addItem(), throwsPartyNotFound());
    });
  });

  group('RemoveItemFromPartyUseCase', () {
    test('remove o item e mantém a festa quando sobram itens', () async {
      await createPlanningParty();
      await addItem();
      await addItem(itemId: 'item-2', externalId: 'listing-2');

      await RemoveItemFromPartyUseCase(repository)(
        partyId: partyId,
        itemId: const PartyItemId('item-1'),
      );

      final stored = (await repository.getById(partyId))!;
      expect(stored.budget.items.single.id, const PartyItemId('item-2'));
    });

    test('apaga a festa quando o último item é removido', () async {
      await createPlanningParty();
      await addItem();

      await RemoveItemFromPartyUseCase(repository)(
        partyId: partyId,
        itemId: const PartyItemId('item-1'),
      );

      expect(await repository.getById(partyId), isNull);
    });

    test('falha para festa ou item inexistente', () async {
      await createPlanningParty();
      await addItem();
      final removeItem = RemoveItemFromPartyUseCase(repository);

      expect(
        removeItem(partyId: missingId, itemId: const PartyItemId('item-1')),
        throwsPartyNotFound(),
      );
      expect(
        removeItem(partyId: partyId, itemId: const PartyItemId('x')),
        throwsA(isA<PartyItemNotFound>()),
      );
    });
  });

  group('RenamePartyTitleUseCase', () {
    test('renomeia e persiste', () async {
      await createPlanningParty();

      await RenamePartyTitleUseCase(repository)(
        partyId: partyId,
        newTitle: PartyTitle('15 anos da Maria'),
      );

      expect(
        (await repository.getById(partyId))!.title.value,
        '15 anos da Maria',
      );
    });

    test('falha para festa inexistente', () {
      expect(
        RenamePartyTitleUseCase(repository)(
          partyId: missingId,
          newTitle: PartyTitle('Qualquer'),
        ),
        throwsPartyNotFound(),
      );
    });
  });

  group('LockPartyForPaymentUseCase / UnlockPartyUseCase', () {
    test('trava gerando snapshot e destrava descartando-o', () async {
      await createPlanningParty();
      await addItem();

      await LockPartyForPaymentUseCase(repository)(partyId);
      final locked = (await repository.getById(partyId))!;
      expect(locked.status, PartyStatus.locked);
      expect(locked.paymentSnapshot!.totalAmount, Money.fromCents(80000));

      await UnlockPartyUseCase(repository)(partyId);
      final unlocked = (await repository.getById(partyId))!;
      expect(unlocked.status, PartyStatus.planning);
      expect(unlocked.paymentSnapshot, isNull);
    });

    test('não trava festa sem itens', () async {
      await createPlanningParty();

      expect(
        LockPartyForPaymentUseCase(repository)(partyId),
        throwsA(isA<CannotLockWithoutItems>()),
      );
    });
  });

  group('CancelPartyUseCase', () {
    test('cancela e devolve o resultado do cancelamento', () async {
      await createPlanningParty();
      await addItem();

      final result = await CancelPartyUseCase(repository)(partyId);

      expect(result.totalAtCancellation, Money.fromCents(80000));
      expect(
        (await repository.getById(partyId))!.status,
        PartyStatus.cancelled,
      );
    });

    test('falha para festa inexistente', () {
      expect(CancelPartyUseCase(repository)(missingId), throwsPartyNotFound());
    });
  });
}
