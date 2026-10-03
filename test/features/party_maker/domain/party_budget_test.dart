import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

import '../party_fixtures.dart';

void main() {
  group('PartyBudget: a composição', () {
    test('começa vazia, sem nada a estimar', () {
      final budget = PartyBudget.empty();

      expect(budget.items, isEmpty);
      expect(budget.isEmpty, isTrue);
      expect(budget.venue, isNull);
      expect(budget.estimateFor(80).total, Money.zero());
      expect(budget.estimateFor(80).isComplete, isTrue);
      expect(budget.quotedTotal, isNull);
    });

    test('é imutável: cada mudança devolve outra composição', () {
      final empty = PartyBudget.empty();

      final withItem = empty.add([buildItem()]);

      expect(empty.items, isEmpty);
      expect(withItem.items, hasLength(1));
      expect(
        () => withItem.items.add(buildItem(id: 'x')),
        throwsUnsupportedError,
      );
    });

    test('encontra itens por id e pela origem', () {
      final item = buildItem();
      final budget = PartyBudget.empty().add([item]);

      expect(budget.findById(item.id), same(item));
      expect(budget.findByExternalRef(item.externalRef), same(item));
      expect(budget.findById(const PartyItemId('x')), isNull);
      expect(
        budget.findByExternalRef(const ExternalRef.listing('outro')),
        isNull,
      );
    });

    test('o mesmo anúncio não entra duas vezes', () {
      final budget = PartyBudget.empty().add([buildItem()]);

      expect(
        () => budget.add([buildItem(id: 'item-2')]),
        throwsA(isA<DuplicatePartyItem>()),
      );
    });

    test('dois itens não podem ter o mesmo id', () {
      final budget = PartyBudget.empty().add([buildItem()]);

      expect(
        () => budget.add([buildItem(externalId: 'listing-2')]),
        throwsA(isA<DuplicatePartyItem>()),
      );
    });

    test('permite apenas um salão por festa', () {
      final budget = PartyBudget.empty().add([buildVenue()]);

      expect(budget.venue!.nameSnapshot, 'Salão Glamour');
      expect(
        () => budget.add([buildVenue(id: 'venue-2', externalId: 'outro')]),
        throwsA(isA<VenueAlreadySelected>()),
      );
    });

    test('tem um teto de itens, o mesmo da API', () {
      final full = PartyBudget.empty().add([
        for (var i = 0; i < PartyBudget.maxItems; i++)
          buildItem(id: 'item-$i', externalId: 'listing-$i'),
      ]);

      expect(
        () => full.add([buildItem(id: 'a-mais', externalId: 'a-mais')]),
        throwsA(isA<TooManyPartyItems>()),
      );
    });

    test('todos os itens ficam na mesma moeda', () {
      final budget = PartyBudget.empty().add([buildItem()]);

      expect(
        () => budget.add([
          buildItem(id: 'item-2', externalId: 'listing-2', currency: 'USD'),
        ]),
        throwsA(
          isA<PartyDomainException>().having(
            (e) => e.code,
            'code',
            'currency_mismatch',
          ),
        ),
      );
    });

    test('troca um item pelo de mesmo id', () {
      final budget = PartyBudget.empty().add([buildItem()]);

      final updated = budget.replace(buildItem(quantity: 4));

      expect(updated.items.single.quantity.value, 4);
      expect(
        () => budget.replace(buildItem(id: 'nao-existe')),
        throwsA(isA<PartyItemNotFound>()),
      );
    });
  });

  group('PartyBudget: a estimativa', () {
    test('soma o que cada item estima, pelo jeito que ele cobra', () {
      final budget = PartyBudget.empty().add([
        // R$ 1.700 fixos
        buildVenue(),
        // R$ 55 x 80 convidados
        buildItem(
          id: 'buffet',
          externalId: 'buffet',
          category: PartyItemCategory.buffet,
          model: PricingModel.perPerson,
          priceCents: 5500,
          configuration: const {'service_style': 'plated'},
        ),
        // R$ 200 x 4 horas
        buildItem(
          id: 'dj',
          externalId: 'dj',
          category: PartyItemCategory.dj,
          model: PricingModel.perHour,
          priceCents: 20000,
          configuration: kFourHours,
        ),
        // R$ 10 x 30 unidades
        buildItem(
          id: 'copos',
          externalId: 'copos',
          model: PricingModel.perUnit,
          priceCents: 1000,
          quantity: 30,
        ),
      ]);

      final estimate = budget.estimateFor(80);

      expect(estimate.total, Money.fromCents(170000 + 440000 + 80000 + 30000));
      expect(estimate.unpricedItems, 0);
      expect(estimate.isComplete, isTrue);
    });

    test('o que é sob consulta fica fora da soma, e é contado', () {
      final budget = PartyBudget.empty().add([
        buildItem(),
        buildItem(
          id: 'decoracao',
          externalId: 'decoracao',
          model: PricingModel.onRequest,
          priceCents: null,
        ),
      ]);

      final estimate = budget.estimateFor(80);

      // O total nunca finge ser completo.
      expect(estimate.total, Money.fromCents(80000));
      expect(estimate.unpricedItems, 1);
      expect(estimate.isComplete, isFalse);
    });

    test('sem o número de convidados, o que é por pessoa não é estimado', () {
      final budget = PartyBudget.empty().add([
        buildItem(model: PricingModel.perPerson, priceCents: 5500),
      ]);

      expect(budget.estimateFor(null).unpricedItems, 1);
      expect(budget.estimateFor(null).total, Money.zero());
      expect(budget.estimateFor(10).total, Money.fromCents(55000));
    });
  });

  group('PartyBudget: o orçamento recebido', () {
    ItemQuote quoted(int cents) =>
        ItemQuote(status: QuoteStatus.quoted, amount: Money.fromCents(cents));

    test('é a soma do que os fornecedores informaram', () {
      final budget = PartyBudget.empty().add([
        buildItem(quote: quoted(90000)),
        buildItem(id: 'item-2', externalId: 'listing-2', quote: quoted(10000)),
        buildItem(
          id: 'item-3',
          externalId: 'listing-3',
          quote: const ItemQuote.pending(),
        ),
      ]);

      expect(budget.quotedTotal, Money.fromCents(100000));
    });

    test('não existe enquanto ninguém deu um valor', () {
      final budget = PartyBudget.empty().add([
        buildItem(quote: const ItemQuote.pending()),
        buildItem(
          id: 'item-2',
          externalId: 'listing-2',
          quote: const ItemQuote(
            status: QuoteStatus.declined,
            message: 'Sem agenda',
          ),
        ),
      ]);

      // Nulo, e não zero: "ninguém respondeu" não é "custa R$ 0".
      expect(budget.quotedTotal, isNull);
    });

    test('withQuotes troca a resposta de cada item', () {
      final budget = PartyBudget.empty().add([buildItem()]);

      final pending = budget.withQuotes((_) => const ItemQuote.pending());

      expect(pending.items.single.quote.status, QuoteStatus.pending);
      expect(budget.items.single.quote.status, QuoteStatus.none);
    });
  });

  group('PartyBudget: itens ligados', () {
    PartyBudget venueWithChildren() {
      return PartyBudget.empty().add([
        buildVenue(),
        buildOwnService(),
        buildOwnService(
          id: 'service-2',
          offerId: 'offer-2',
          name: 'Taxa de limpeza',
          category: PartyItemCategory.other,
          model: PricingModel.fixed,
          priceCents: 15000,
          isRequired: true,
        ),
        buildItem(
          id: 'partner-1',
          externalId: 'listing-decoracao',
          name: 'Decoração Encanto',
          relation: const ItemRelation.recommendedBy(PartyItemId('venue-1')),
        ),
      ]);
    }

    test('lista os itens ligados a outro', () {
      final budget = venueWithChildren();

      expect(
        budget.childrenOf(const PartyItemId('venue-1')).map((i) => i.id.value),
        ['service-1', 'service-2', 'partner-1'],
      );
      expect(budget.childrenOf(const PartyItemId('service-1')), isEmpty);
    });

    test('um item só se liga a um item que está na festa', () {
      expect(
        () => PartyBudget.empty().add([buildOwnService()]),
        throwsA(isA<ParentItemMissing>()),
      );
    });

    test('não há cadeias: quem está ligado a outro não tem itens ligados', () {
      final budget = PartyBudget.empty().add([buildVenue(), buildOwnService()]);

      expect(
        () => budget.add([
          buildOwnService(
            id: 'service-9',
            offerId: 'offer-9',
            parentId: 'service-1',
          ),
        ]),
        throwsA(isA<InvalidItemRelation>()),
      );
    });

    test('um item não se liga a si mesmo', () {
      expect(
        () => PartyBudget.empty().add([
          buildItem(
            relation: const ItemRelation.linkedTo(PartyItemId('item-1')),
          ),
        ]),
        throwsA(isA<InvalidItemRelation>()),
      );
    });

    test('removalOf diz o que sai junto e o que fica solto, sem remover', () {
      final budget = venueWithChildren();

      final removal = budget.removalOf(const PartyItemId('venue-1'));

      expect(removal.item.nameSnapshot, 'Salão Glamour');
      expect(removal.removedWith.map((i) => i.nameSnapshot), [
        'Buffet do salão',
        'Taxa de limpeza',
      ]);
      expect(removal.released.map((i) => i.nameSnapshot), [
        'Decoração Encanto',
      ]);
      expect(budget.items, hasLength(4));
    });

    test('remover um item leva os serviços dele e solta os parceiros', () {
      final budget = venueWithChildren().remove(const PartyItemId('venue-1'));

      // O parceiro recomendado é um anúncio à parte: continua, por conta
      // própria.
      final partner = budget.items.single;
      expect(partner.nameSnapshot, 'Decoração Encanto');
      expect(partner.relation, const ItemRelation.independent());
    });

    test('remover um serviço não mexe no anúncio nem nos outros', () {
      final budget = venueWithChildren().remove(const PartyItemId('service-1'));

      expect(budget.items.map((i) => i.id.value), [
        'venue-1',
        'service-2',
        'partner-1',
      ]);
    });

    test('remover um item que não existe falha', () {
      expect(
        () => PartyBudget.empty().remove(const PartyItemId('x')),
        throwsA(isA<PartyItemNotFound>()),
      );
    });
  });
}
