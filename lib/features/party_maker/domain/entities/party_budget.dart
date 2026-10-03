import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// A soma do que dá para estimar em uma festa.
///
/// [unpricedItems] diz quantos itens ficaram de fora dela (sob consulta, ou
/// sem a medida de que o preço depende): o total nunca finge ser completo.
class BudgetEstimate {
  const BudgetEstimate({required this.total, required this.unpricedItems});

  final Money total;
  final int unpricedItems;

  bool get isComplete => unpricedItems == 0;
}

/// O que a remoção de um item faz com os outros.
class ItemRemoval {
  const ItemRemoval({
    required this.item,
    this.removedWith = const [],
    this.released = const [],
  });

  /// O item que a pessoa pediu para tirar.
  final PartyItem item;

  /// Os serviços do próprio item, que não existem sem ele e saem junto.
  final List<PartyItem> removedWith;

  /// Os itens que ele tinha recomendado: são anúncios à parte e continuam na
  /// festa, por conta própria.
  final List<PartyItem> released;
}

/// A composição da festa: os itens escolhidos e o que eles somam.
/// É imutável: cada mudança devolve outra composição.
class PartyBudget {
  /// O mesmo teto da API (`MAX_ITEMS_PER_PARTY`).
  static const int maxItems = 50;

  final List<PartyItem> _items;

  PartyBudget._(List<PartyItem> items) : _items = List.unmodifiable(items);

  factory PartyBudget.empty() => PartyBudget._([]);

  /// Reconstrói uma composição que já foi gravada (por um repositório). Não
  /// revalida: os itens já passaram pelas regras quando entraram.
  factory PartyBudget.restore(Iterable<PartyItem> items) {
    return PartyBudget._(items.toList());
  }

  List<PartyItem> get items => _items;

  bool get isEmpty => _items.isEmpty;

  /// O salão da festa, se já foi escolhido. Só pode haver um.
  PartyItem? get venue {
    for (final item in _items) {
      if (item.category == PartyItemCategory.venue) return item;
    }
    return null;
  }

  PartyItem? findById(PartyItemId id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  PartyItem? findByExternalRef(ExternalRef ref) {
    for (final item in _items) {
      if (item.externalRef == ref) return item;
    }
    return null;
  }

  /// Os itens ligados a [id]: serviços próprios e parceiros que ele indicou.
  List<PartyItem> childrenOf(PartyItemId id) {
    return [
      for (final item in _items)
        if (item.relation.parentId == id) item,
    ];
  }

  // ---------------------------------------------------------------
  // Valores
  // ---------------------------------------------------------------

  /// A estimativa da festa para [guests] convidados.
  BudgetEstimate estimateFor(int? guests) {
    var total = Money.zero(currency: _currency);
    var unpriced = 0;
    for (final item in _items) {
      final estimate = item.estimate(guests: guests);
      if (estimate == null) {
        unpriced++;
      } else {
        total = total + estimate;
      }
    }
    return BudgetEstimate(total: total, unpricedItems: unpriced);
  }

  /// A soma do que os fornecedores já informaram, ou `null` se nenhum
  /// respondeu com um valor.
  Money? get quotedTotal {
    Money? total;
    for (final item in _items) {
      final amount = item.quote.isQuoted ? item.quote.amount : null;
      if (amount == null) continue;
      total = (total ?? Money.zero(currency: _currency)) + amount;
    }
    return total;
  }

  String get _currency =>
      _items.isEmpty ? 'BRL' : _items.first.pricing.currency;

  // ---------------------------------------------------------------
  // Mudanças
  // ---------------------------------------------------------------

  /// Acrescenta [newItems] de uma vez: um anúncio entra junto com os serviços
  /// próprios escolhidos, ou não entra.
  PartyBudget add(List<PartyItem> newItems) {
    final all = [..._items, ...newItems];
    if (all.length > maxItems) throw const TooManyPartyItems(maxItems);

    final ids = <PartyItemId>{};
    final sources = <ExternalRef>{};
    for (final item in all) {
      if (!ids.add(item.id) || !sources.add(item.externalRef)) {
        throw const DuplicatePartyItem();
      }
    }
    if (all.where((i) => i.category == PartyItemCategory.venue).length > 1) {
      throw const VenueAlreadySelected();
    }
    if (all.any(
      (item) => item.pricing.currency != all.first.pricing.currency,
    )) {
      throw const PartyDomainException(
        'currency_mismatch',
        'Todos os itens da festa precisam estar na mesma moeda.',
      );
    }

    final byId = {for (final item in all) item.id: item};
    for (final item in newItems) {
      final parentId = item.relation.parentId;
      if (parentId == null) continue;
      final parent = byId[parentId];
      if (parent == null) throw const ParentItemMissing();
      // Sem cadeias: um item ligado a outro não tem itens ligados a ele.
      if (parent.id == item.id || parent.relation.parentId != null) {
        throw const InvalidItemRelation();
      }
    }
    return PartyBudget._(all);
  }

  /// Troca o item de mesmo id por [item].
  PartyBudget replace(PartyItem item) {
    if (findById(item.id) == null) throw const PartyItemNotFound();
    return PartyBudget._([
      for (final current in _items) current.id == item.id ? item : current,
    ]);
  }

  /// O que tirar [id] faria, sem tirar: é o que a tela mostra antes de pedir a
  /// confirmação.
  ItemRemoval removalOf(PartyItemId id) {
    final item = findById(id);
    if (item == null) throw const PartyItemNotFound();

    final children = childrenOf(id);
    return ItemRemoval(
      item: item,
      removedWith: [
        for (final child in children)
          if (child.relation.isOwnService) child,
      ],
      released: [
        for (final child in children)
          if (!child.relation.isOwnService) child,
      ],
    );
  }

  /// Tira o item e, com ele, os serviços que não existem sem ele; os itens que
  /// ele tinha recomendado ficam, soltos.
  PartyBudget remove(PartyItemId id) {
    final removal = removalOf(id);
    final leaving = {id, for (final item in removal.removedWith) item.id};
    final released = {for (final item in removal.released) item.id};

    return PartyBudget._([
      for (final item in _items)
        if (!leaving.contains(item.id))
          released.contains(item.id)
              ? item.copyWith(relation: const ItemRelation.independent())
              : item,
    ]);
  }

  /// A mesma composição, com o orçamento de cada item trocado por [update].
  PartyBudget withQuotes(ItemQuote Function(PartyItem item) update) {
    return PartyBudget._([
      for (final item in _items) item.copyWith(quote: update(item)),
    ]);
  }
}
