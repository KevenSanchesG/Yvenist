import '../enums/party_item_category.dart';
import '../value_objects/external_ref.dart';
import '../value_objects/money.dart';
import '../value_objects/party_item_id.dart';
import '../value_objects/quantity.dart';

class PartyItem {
  final PartyItemId id;                 // interno (do aggregate)
  final ExternalRef externalRef;         // referência externa
  final PartyItemCategory category;      // ex: venue
  final String nameSnapshot;             // conforto do usuário
  final Money unitPriceSnapshot;         // snapshot no momento
  final Quantity quantity;

  const PartyItem({
    required this.id,
    required this.externalRef,
    required this.category,
    required this.nameSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
  });

  Money get subtotal => unitPriceSnapshot.multiplyInt(quantity.value);

  PartyItem withQuantity(Quantity q) => PartyItem(
        id: id,
        externalRef: externalRef,
        category: category,
        nameSnapshot: nameSnapshot,
        unitPriceSnapshot: unitPriceSnapshot,
        quantity: q,
      );

  PartyItem withUnitPrice(Money newPrice) => PartyItem(
        id: id,
        externalRef: externalRef,
        category: category,
        nameSnapshot: nameSnapshot,
        unitPriceSnapshot: newPrice,
        quantity: quantity,
      );
}
