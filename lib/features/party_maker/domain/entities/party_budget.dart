import '../enums/party_item_category.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/external_ref.dart';
import '../value_objects/money.dart';
import '../value_objects/party_item_id.dart';
import '../value_objects/quantity.dart';
import 'party_item.dart';

class PartyBudget {
  final List<PartyItem> _items;

  PartyBudget._(List<PartyItem> items) : _items = List.unmodifiable(items);

  factory PartyBudget.empty() => PartyBudget._([]);

  /// Reconstrói um orçamento que já foi gravado (por um repositório). Não
  /// mescla nem revalida: os itens já passaram pelas regras quando entraram.
  factory PartyBudget.restore(Iterable<PartyItem> items) {
    return PartyBudget._(items.toList());
  }

  List<PartyItem> get items => _items;

  Money get total {
    if (_items.isEmpty) return Money.zero();
    final currency = _items.first.unitPriceSnapshot.currency;
    Money sum = Money.zero(currency: currency);
    for (final i in _items) {
      sum = sum + i.subtotal;
    }
    // Domínio impede consolidado < 0
    if (sum.isNegative) {
      throw const BudgetWouldBecomeNegative();
    }
    return sum;
  }

  bool hasVenue() => _items.any((i) => i.category == PartyItemCategory.venue);

  PartyItem? findById(PartyItemId id) {
    for (final i in _items) {
      if (i.id == id) return i;
    }
    return null;
  }

  PartyItem? findByExternalRef(ExternalRef ref) {
    for (final i in _items) {
      if (i.externalRef == ref) return i;
    }
    return null;
  }

  PartyBudget addOrMergeItem({
    required PartyItem newItem,
  }) {
    // Invariante: venue único
    if (newItem.category == PartyItemCategory.venue && hasVenue()) {
      // Se já existe venue (mesmo externalRef) ainda assim faz sentido bloquear,
      // porque venue duplicado tende a ser erro de UX.
      throw const VenueAlreadySelected();
    }

    final existing = findByExternalRef(newItem.externalRef);
    if (existing == null) {
      final updated = [..._items, newItem];
      return PartyBudget._(updated);
    }

    // Regra: mescla por externalRef (soma quantity)
    final merged = existing.withQuantity(existing.quantity.add(newItem.quantity));
    final updated = _items.map((i) => i.id == existing.id ? merged : i).toList();
    return PartyBudget._(updated);
  }

  PartyBudget removeItem(PartyItemId id) {
    final exists = findById(id);
    if (exists == null) throw const PartyItemNotFound();
    final updated = _items.where((i) => i.id != id).toList();
    return PartyBudget._(updated);
  }

  PartyBudget updateQuantity(PartyItemId id, Quantity q) {
    final item = findById(id);
    if (item == null) throw const PartyItemNotFound();
    final updated = _items.map((i) => i.id == id ? i.withQuantity(q) : i).toList();
    return PartyBudget._(updated);
  }

  PartyBudget updateUnitPrice(PartyItemId id, Money newPrice) {
    final item = findById(id);
    if (item == null) throw const PartyItemNotFound();
    final updated = _items.map((i) => i.id == id ? i.withUnitPrice(newPrice) : i).toList();
    return PartyBudget._(updated);
  }
}
