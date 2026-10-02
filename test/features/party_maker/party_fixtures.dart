import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Fábricas de objetos de domínio usadas pelos testes do Party Maker.

final DateTime kFixedNow = DateTime(2026, 1, 15, 12);

Party buildParty({
  String id = 'party-1',
  String ownerId = 'user-1',
  String title = 'Aniversário da Ana',
}) {
  return Party(
    id: PartyId(id),
    ownerId: ownerId,
    title: PartyTitle(title),
    createdAt: kFixedNow,
    updatedAt: kFixedNow,
  );
}

PartyItem buildItem({
  String id = 'item-1',
  String externalId = 'listing-1',
  String source = 'vendor_catalog',
  PartyItemCategory category = PartyItemCategory.other,
  String name = 'DJ Festa Boa',
  int unitPriceCents = 80000,
  String currency = 'BRL',
  int quantity = 1,
}) {
  return PartyItem(
    id: PartyItemId(id),
    externalRef: ExternalRef(source: source, id: externalId),
    category: category,
    nameSnapshot: name,
    unitPriceSnapshot: Money.fromCents(unitPriceCents, currency: currency),
    quantity: Quantity(quantity),
  );
}

/// Adiciona um item a [party] usando os mesmos valores padrão de [buildItem].
void addItemTo(
  Party party, {
  String id = 'item-1',
  String externalId = 'listing-1',
  PartyItemCategory category = PartyItemCategory.other,
  String name = 'DJ Festa Boa',
  int unitPriceCents = 80000,
  int quantity = 1,
}) {
  party.addItem(
    partyItemId: PartyItemId(id),
    externalRef: ExternalRef(source: 'vendor_catalog', id: externalId),
    category: category,
    nameSnapshot: name,
    unitPriceSnapshot: Money.fromCents(unitPriceCents),
    quantity: Quantity(quantity),
  );
}
