import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

import '../party_fixtures.dart';

/// Festa em planejamento com um item, pronta para ser travada.
Party planningPartyWithItem() {
  final party = buildParty()..startPlanning();
  addItemTo(party, unitPriceCents: 80000, quantity: 2);
  return party;
}

void main() {
  group('Party: criação', () {
    test('nasce como rascunho, sem itens e sem snapshot', () {
      final party = buildParty();

      expect(party.status, PartyStatus.draft);
      expect(party.budget.items, isEmpty);
      expect(party.paymentSnapshot, isNull);
      expect(party.eventDate, isNull);
      expect(party.guestCount, isNull);
    });
  });

  group('Party: planejamento', () {
    test('rascunho pode iniciar o planejamento', () {
      final party = buildParty()..startPlanning();

      expect(party.status, PartyStatus.planning);
    });

    test('só inicia o planejamento a partir de rascunho', () {
      final party = buildParty()..startPlanning();

      expect(party.startPlanning, throwsA(isA<InvalidPartyTransition>()));
    });

    test('permite editar título, data e convidados', () {
      final party = buildParty()..startPlanning();
      final date = EventDate(DateTime(2026, 12, 25));

      party
        ..rename(PartyTitle('Natal em família'))
        ..setEventDate(date)
        ..setGuestCount(GuestCount(40));

      expect(party.title.value, 'Natal em família');
      expect(party.eventDate, date);
      expect(party.guestCount, GuestCount(40));
    });

    test('toda mutação atualiza updatedAt', () {
      final party = buildParty();
      final before = party.updatedAt;

      party.startPlanning();

      expect(party.updatedAt.isAfter(before), isTrue);
      expect(party.createdAt, kFixedNow);
    });
  });

  group('Party: itens', () {
    test('aceita itens em rascunho e em planejamento', () {
      final draft = buildParty();
      addItemTo(draft);

      final planning = buildParty()..startPlanning();
      addItemTo(planning);

      expect(draft.budget.items, hasLength(1));
      expect(planning.budget.items, hasLength(1));
    });

    test('remove e altera itens existentes', () {
      final party = planningPartyWithItem();
      const itemId = PartyItemId('item-1');

      party
        ..updateItemQuantity(itemId, Quantity(5))
        ..updateItemPrice(itemId, Money.fromCents(100));
      expect(party.budget.total, Money.fromCents(500));

      party.removeItem(itemId);
      expect(party.budget.items, isEmpty);
    });

    test('mantém a regra de salão único', () {
      final party = buildParty()..startPlanning();
      addItemTo(party, category: PartyItemCategory.venue);

      expect(
        () => addItemTo(
          party,
          id: 'item-2',
          externalId: 'listing-2',
          category: PartyItemCategory.venue,
        ),
        throwsA(isA<VenueAlreadySelected>()),
      );
    });

    test('festa travada não aceita mudanças nos itens', () {
      final party = planningPartyWithItem()..lockForPayment();
      const itemId = PartyItemId('item-1');

      expect(
        () => addItemTo(party, id: 'item-2', externalId: 'listing-2'),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        () => party.removeItem(itemId),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        () => party.updateItemQuantity(itemId, Quantity(2)),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        () => party.updateItemPrice(itemId, Money.zero()),
        throwsA(isA<InvalidPartyTransition>()),
      );
    });
  });

  group('Party: travar para pagamento', () {
    test('gera o snapshot com total e detalhamento', () {
      final party = planningPartyWithItem()..lockForPayment();

      final snapshot = party.paymentSnapshot!;
      expect(party.status, PartyStatus.locked);
      expect(snapshot.partyId, party.id);
      expect(snapshot.totalAmount, Money.fromCents(160000));
      expect(snapshot.breakdown, hasLength(1));
      expect(snapshot.breakdown.single.subtotal, Money.fromCents(160000));
      expect(snapshot.breakdown.single.nameSnapshot, 'DJ Festa Boa');
    });

    test('exige estar em planejamento', () {
      final draft = buildParty();
      addItemTo(draft);

      expect(draft.lockForPayment, throwsA(isA<InvalidPartyTransition>()));
    });

    test('exige ao menos um item', () {
      final party = buildParty()..startPlanning();

      expect(party.lockForPayment, throwsA(isA<CannotLockWithoutItems>()));
    });

    test('festa travada não aceita edição de dados', () {
      final party = planningPartyWithItem()..lockForPayment();

      expect(
        () => party.updateTitle(PartyTitle('Outro nome')),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
      expect(
        () => party.setGuestCount(GuestCount(10)),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
      expect(
        () => party.setEventDate(EventDate(DateTime(2027))),
        throwsA(isA<PartyLockedMutationNotAllowed>()),
      );
    });

    test('destravar volta ao planejamento e descarta o snapshot', () {
      final party = planningPartyWithItem()
        ..lockForPayment()
        ..unlock();

      expect(party.status, PartyStatus.planning);
      expect(party.paymentSnapshot, isNull);
    });

    test('só destrava festa travada', () {
      final party = planningPartyWithItem();

      expect(party.unlock, throwsA(isA<InvalidPartyTransition>()));
    });
  });

  group('Party: pagamento', () {
    test('confirma o pagamento a partir de travada', () {
      final party = planningPartyWithItem()
        ..lockForPayment()
        ..confirmPayment();

      expect(party.status, PartyStatus.paid);
      expect(party.paymentSnapshot, isNotNull);
    });

    test('não confirma pagamento sem travar antes', () {
      final party = planningPartyWithItem();

      expect(party.confirmPayment, throwsA(isA<InvalidPartyTransition>()));
    });

    test('festa paga não aceita edição nem itens', () {
      final party = planningPartyWithItem()
        ..lockForPayment()
        ..confirmPayment();

      expect(
        () => party.updateTitle(PartyTitle('Outro nome')),
        throwsA(isA<InvalidPartyTransition>()),
      );
      expect(
        () => addItemTo(party, id: 'item-2', externalId: 'listing-2'),
        throwsA(isA<InvalidPartyTransition>()),
      );
    });
  });

  group('Party: cancelamento', () {
    test('cancela em planejamento informando o total no momento', () {
      final party = planningPartyWithItem();

      final result = party.cancel();

      expect(party.status, PartyStatus.cancelled);
      expect(result.totalAtCancellation, Money.fromCents(160000));
      expect(result.refundAmount, Money.zero());
      expect(result.penaltyAmount, Money.zero());
      expect(result.hasRefund, isFalse);
    });

    test('cancela rascunho sem itens com total zero', () {
      final party = buildParty();

      expect(party.cancel().totalAtCancellation, Money.zero());
      expect(party.status, PartyStatus.cancelled);
    });

    test('cancelar festa travada invalida o snapshot', () {
      final party = planningPartyWithItem()..lockForPayment();

      party.cancel();

      expect(party.status, PartyStatus.cancelled);
      expect(party.paymentSnapshot, isNull);
    });

    test('no MVP não cancela festa já paga', () {
      final party = planningPartyWithItem()
        ..lockForPayment()
        ..confirmPayment();

      expect(party.cancel, throwsA(isA<CannotCancelAfterPaidInMvp>()));
    });

    test('não cancela duas vezes nem edita festa cancelada', () {
      final party = buildParty()..cancel();

      expect(party.cancel, throwsA(isA<InvalidPartyTransition>()));
      expect(
        () => party.updateTitle(PartyTitle('Outro nome')),
        throwsA(isA<InvalidPartyTransition>()),
      );
    });
  });
}
