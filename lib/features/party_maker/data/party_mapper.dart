import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/utils/clock.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request_snapshot.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Tradução entre o JSON da API e o agregado [Party].

Party partyFromJson(Json json, {Clock clock = systemClock}) {
  final currency = json['currency'] as String? ?? 'BRL';
  final eventAt = json['event_at'] as String?;
  final guestCount = json['guest_count'] as int?;
  final snapshot = json['snapshot'] as Json?;

  return Party(
    id: PartyId(json['id'] as String),
    ownerId: json['owner_id'] as String,
    title: PartyTitle(json['title'] as String),
    eventType: json['event_type'] as String?,
    eventDate: eventAt == null ? null : EventDate(DateTime.parse(eventAt)),
    guestCount: guestCount == null ? null : GuestCount(guestCount),
    status: PartyStatus.fromApi(json['status']),
    budget: PartyBudget.restore(
      (json['items'] as List).cast<Json>().map(_itemFromJson),
    ),
    quoteSnapshot: snapshot == null
        ? null
        : _snapshotFromJson(snapshot, currency),
    quoteRound: json['quote_round'] as int? ?? 0,
    history: [
      for (final entry in (json['history'] as List? ?? const []).cast<Json>())
        ?_historyFromJson(entry, currency),
    ],
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    clock: clock,
  );
}

/// Estado que o app quer gravar. De cada item vai só de onde ele vem, a
/// quantidade, a configuração e a que item ele se liga: nome, preço, forma de
/// cobrança e a própria relação são conferidos e copiados do catálogo pelo
/// servidor.
Json partyToJson(Party party, {required int? version}) {
  return {
    'title': party.title.value,
    'event_type': party.eventType,
    'event_at': party.eventDate?.value.toUtc().toIso8601String(),
    'guest_count': party.guestCount?.value,
    'status': _requestedStatus(party.status),
    'items': [
      for (final item in party.budget.items)
        {
          'id': item.id.value,
          'listing_id': item.externalRef.isListing ? item.externalRef.id : null,
          'offer_id': item.externalRef.isOffer ? item.externalRef.id : null,
          'parent_item_id': item.relation.parentId?.value,
          'quantity': item.quantity.value,
          'configuration': item.configuration.values,
        },
    ],
    'version': ?version,
  };
}

/// Um pedido de orçamento como o fornecedor o recebe.
QuoteRequest quoteRequestFromJson(Json json) {
  final currency = json['currency'] as String? ?? 'BRL';
  final eventAt = json['event_at'] as String?;

  return QuoteRequest(
    itemId: json['item_id'] as String,
    partyId: json['party_id'] as String,
    partyStatus: PartyStatus.fromApi(json['party_status']),
    round: json['quote_round'] as int,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    eventType: json['event_type'] as String?,
    eventDate: eventAt == null ? null : DateTime.parse(eventAt),
    guestCount: json['guest_count'] as int?,
    name: json['name'] as String,
    category: PartyItemCategory.fromSlug(json['category'] as String),
    relation: ItemRelationKind.fromApi(json['relation']),
    parentName: json['parent_name'] as String?,
    pricing: _pricingFromJson(json, currency),
    quantity: json['quantity'] as int,
    configuration: _configurationFromJson(json['configuration']),
    estimate: _money(json['estimate_cents'], currency),
    quote: _quoteFromJson(json['quote'] as Json, currency),
  );
}

/// O que o cliente pede é "solicitar o orçamento". Se a festa sai dali como
/// "orçamento recebido" ou "edição solicitada", quem decide é o servidor, pelo
/// que cada fornecedor já respondeu: esses dois status nunca são enviados.
String _requestedStatus(PartyStatus status) {
  return switch (status) {
    PartyStatus.quoted ||
    PartyStatus.editRequested => PartyStatus.locked.apiValue,
    _ => status.apiValue,
  };
}

PartyItem _itemFromJson(Json json) {
  final id = json['id'] as String;
  final listingId = json['listing_id'] as String?;
  final offerId = json['offer_id'] as String?;
  final parentId = json['parent_item_id'] as String?;
  final currency = json['currency'] as String? ?? 'BRL';

  return PartyItem(
    id: PartyItemId(id),
    // Sem anúncio e sem serviço próprio, a origem do item saiu do catálogo:
    // ficou só a cópia.
    externalRef: offerId != null
        ? ExternalRef.offer(offerId)
        : listingId != null
        ? ExternalRef.listing(listingId)
        : ExternalRef.unavailable(id),
    category: PartyItemCategory.fromSlug(json['category'] as String),
    nameSnapshot: json['name'] as String,
    pricing: _pricingFromJson(json, currency),
    quantity: Quantity(json['quantity'] as int),
    configuration: _configurationFromJson(json['configuration']),
    relation: ItemRelation.restore(
      ItemRelationKind.fromApi(json['relation']),
      parentId == null ? null : PartyItemId(parentId),
    ),
    quote: _quoteFromJson(json['quote'] as Json?, currency),
    imageUrlSnapshot: json['image_url'] as String?,
    capacity: json['capacity'] as int?,
    vendorId: json['vendor_id'] as String?,
  );
}

Pricing _pricingFromJson(Json json, String currency) {
  return Pricing(
    model: PricingModel.fromApi(json['pricing_model']),
    amount: _money(json['unit_price_cents'], currency),
    minimum: _money(json['minimum_cents'], currency),
    currency: currency,
  );
}

/// Só o que o domínio sabe guardar: um inteiro ou um texto por campo. Um valor
/// de outro tipo, que o app não saberia mostrar, fica de fora.
ItemConfiguration _configurationFromJson(Object? json) {
  if (json is! Map) return ItemConfiguration.empty;
  return ItemConfiguration({
    for (final entry in json.entries)
      if (entry.key is String && (entry.value is int || entry.value is String))
        entry.key as String: entry.value as Object,
  });
}

ItemQuote _quoteFromJson(Json? json, String currency) {
  if (json == null) return const ItemQuote.none();
  final respondedAt = json['responded_at'] as String?;

  return ItemQuote(
    status: QuoteStatus.fromApi(json['status']),
    amount: _money(json['amount_cents'], currency),
    message: json['message'] as String?,
    respondedAt: respondedAt == null ? null : DateTime.parse(respondedAt),
  );
}

QuoteRequestSnapshot _snapshotFromJson(Json json, String currency) {
  final lines = (json['breakdown'] as List? ?? const []).cast<Json>();
  return QuoteRequestSnapshot(
    requestedAt: DateTime.parse(json['generated_at'] as String),
    estimatedTotal: Money.fromCents(
      json['total_cents'] as int,
      currency: json['currency'] as String? ?? currency,
    ),
    unpricedItems: lines.where((l) => l['subtotal_cents'] == null).length,
  );
}

/// `null` para um acontecimento que o app ainda não conhece: fica fora da
/// lista, em vez de aparecer com o texto errado.
PartyHistoryEntry? _historyFromJson(Json json, String currency) {
  final kind = PartyHistoryKind.fromApi(json['kind']);
  if (kind == null) return null;
  final itemId = json['item_id'] as String?;

  return PartyHistoryEntry(
    kind: kind,
    actor: json['actor'] == 'vendor'
        ? PartyHistoryActor.vendor
        : PartyHistoryActor.client,
    round: json['quote_round'] as int? ?? 0,
    at: DateTime.parse(json['created_at'] as String),
    itemId: itemId == null ? null : PartyItemId(itemId),
    itemName: json['item_name'] as String?,
    message: json['message'] as String?,
    amount: _money(json['amount_cents'], currency),
  );
}

Money? _money(Object? cents, String currency) {
  return cents is int ? Money.fromCents(cents, currency: currency) : null;
}
