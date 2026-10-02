import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

class PartyItem {
  const PartyItem({
    required this.id,
    required this.externalRef,
    required this.category,
    required this.nameSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    this.imageUrlSnapshot,
  });

  final PartyItemId id; // interno (do aggregate)
  final ExternalRef externalRef; // referência externa
  final PartyItemCategory category; // ex: venue
  final String nameSnapshot; // conforto do usuário
  final Money unitPriceSnapshot; // snapshot no momento
  final Quantity quantity;

  /// Capa do anúncio no momento em que o item entrou, como o nome: serve para
  /// o usuário reconhecer o item mesmo que o anúncio mude ou saia do catálogo.
  final String? imageUrlSnapshot;

  Money get subtotal => unitPriceSnapshot.multiplyInt(quantity.value);

  PartyItem withQuantity(Quantity q) => PartyItem(
    id: id,
    externalRef: externalRef,
    category: category,
    nameSnapshot: nameSnapshot,
    unitPriceSnapshot: unitPriceSnapshot,
    quantity: q,
    imageUrlSnapshot: imageUrlSnapshot,
  );

  PartyItem withUnitPrice(Money newPrice) => PartyItem(
    id: id,
    externalRef: externalRef,
    category: category,
    nameSnapshot: nameSnapshot,
    unitPriceSnapshot: newPrice,
    quantity: quantity,
    imageUrlSnapshot: imageUrlSnapshot,
  );
}
