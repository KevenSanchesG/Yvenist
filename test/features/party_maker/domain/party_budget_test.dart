import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

import '../party_fixtures.dart';

void main() {
  group('PartyBudget', () {
    test('começa vazio e com total zero', () {
      final budget = PartyBudget.empty();

      expect(budget.items, isEmpty);
      expect(budget.total, Money.zero());
      expect(budget.hasVenue(), isFalse);
    });

    test('é imutável: cada operação devolve um novo orçamento', () {
      final empty = PartyBudget.empty();

      final withItem = empty.addOrMergeItem(newItem: buildItem());

      expect(empty.items, isEmpty);
      expect(withItem.items, hasLength(1));
      expect(
        () => withItem.items.add(buildItem(id: 'x')),
        throwsUnsupportedError,
      );
    });

    test('soma os subtotais (preço unitário x quantidade)', () {
      final budget = PartyBudget.empty()
          .addOrMergeItem(
            newItem: buildItem(unitPriceCents: 80000, quantity: 2),
          )
          .addOrMergeItem(
            newItem: buildItem(
              id: 'item-2',
              externalId: 'listing-2',
              unitPriceCents: 15050,
            ),
          );

      expect(budget.total, Money.fromCents(175050));
    });

    test('mescla itens com a mesma referência externa somando quantidades', () {
      final budget = PartyBudget.empty()
          .addOrMergeItem(newItem: buildItem(id: 'item-1', quantity: 1))
          .addOrMergeItem(newItem: buildItem(id: 'item-2', quantity: 2));

      expect(budget.items, hasLength(1));
      expect(budget.items.single.id, const PartyItemId('item-1'));
      expect(budget.items.single.quantity, Quantity(3));
    });

    test('permite apenas um salão (venue) por festa', () {
      final budget = PartyBudget.empty().addOrMergeItem(
        newItem: buildItem(category: PartyItemCategory.venue),
      );

      expect(budget.hasVenue(), isTrue);
      expect(
        () => budget.addOrMergeItem(
          newItem: buildItem(
            id: 'item-2',
            externalId: 'listing-2',
            category: PartyItemCategory.venue,
          ),
        ),
        throwsA(isA<VenueAlreadySelected>()),
      );
    });

    test('remove item existente e falha para item desconhecido', () {
      final budget = PartyBudget.empty().addOrMergeItem(newItem: buildItem());

      expect(budget.removeItem(const PartyItemId('item-1')).items, isEmpty);
      expect(
        () => budget.removeItem(const PartyItemId('nao-existe')),
        throwsA(isA<PartyItemNotFound>()),
      );
    });

    test('atualiza quantidade e preço unitário de um item', () {
      final budget = PartyBudget.empty().addOrMergeItem(newItem: buildItem());

      final updated = budget
          .updateQuantity(const PartyItemId('item-1'), Quantity(4))
          .updateUnitPrice(const PartyItemId('item-1'), Money.fromCents(1000));

      expect(updated.items.single.quantity, Quantity(4));
      expect(updated.total, Money.fromCents(4000));
    });

    test('atualizações em item desconhecido falham', () {
      final budget = PartyBudget.empty();

      expect(
        () => budget.updateQuantity(const PartyItemId('x'), Quantity(1)),
        throwsA(isA<PartyItemNotFound>()),
      );
      expect(
        () => budget.updateUnitPrice(const PartyItemId('x'), Money.zero()),
        throwsA(isA<PartyItemNotFound>()),
      );
    });

    test('encontra itens por id e por referência externa', () {
      final item = buildItem();
      final budget = PartyBudget.empty().addOrMergeItem(newItem: item);

      expect(budget.findById(item.id), same(item));
      expect(budget.findByExternalRef(item.externalRef), same(item));
      expect(budget.findById(const PartyItemId('x')), isNull);
    });
  });
}
