import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_payment_snapshot.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Tradução entre o JSON da API e o agregado [Party].

// Um item cujo anúncio foi apagado não tem mais id de anúncio; o domínio
// precisa de uma referência, então usamos uma marcada como órfã.
const String _orphanPrefix = 'removed:';

Party partyFromJson(Json json) {
  final partyId = PartyId(json['id'] as String);
  final eventAt = json['event_at'] as String?;
  final guestCount = json['guest_count'] as int?;
  final snapshot = json['snapshot'] as Json?;

  return Party(
    id: partyId,
    ownerId: json['owner_id'] as String,
    title: PartyTitle(json['title'] as String),
    eventDate: eventAt == null ? null : EventDate(DateTime.parse(eventAt)),
    guestCount: guestCount == null ? null : GuestCount(guestCount),
    status: PartyStatus.values.byName(json['status'] as String),
    budget: PartyBudget.restore(
      (json['items'] as List).cast<Json>().map(_itemFromJson),
    ),
    paymentSnapshot:
        snapshot == null ? null : _snapshotFromJson(partyId, snapshot),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

/// Estado que o app quer gravar. Nome, categoria e preço dos itens não vão:
/// o servidor copia esses dados do catálogo.
Json partyToJson(Party party, {required int? version}) {
  return {
    'title': party.title.value,
    'event_at': party.eventDate?.value.toUtc().toIso8601String(),
    'guest_count': party.guestCount?.value,
    'status': party.status.name,
    'items': [
      for (final item in party.budget.items)
        {
          'id': item.id.value,
          'listing_id': _listingId(item.externalRef),
          'quantity': item.quantity.value,
        },
    ],
    'version': ?version,
  };
}

PartyItem _itemFromJson(Json json) {
  final id = json['id'] as String;
  final listingId = json['listing_id'] as String?;
  final category = json['category'] as String;
  final currency = json['currency'] as String? ?? 'BRL';

  return PartyItem(
    id: PartyItemId(id),
    externalRef: ExternalRef.listing(listingId ?? '$_orphanPrefix$id'),
    category: PartyItemCategory.fromSlug(category),
    nameSnapshot: json['name'] as String,
    unitPriceSnapshot: Money.fromCents(
      json['unit_price_cents'] as int,
      currency: currency,
    ),
    quantity: Quantity(json['quantity'] as int),
    imageUrlSnapshot: json['image_url'] as String?,
  );
}

PartyPaymentSnapshot _snapshotFromJson(PartyId partyId, Json json) {
  final currency = json['currency'] as String? ?? 'BRL';
  final expiresAt = json['expires_at'] as String?;

  return PartyPaymentSnapshot(
    partyId: partyId,
    generatedAt: DateTime.parse(json['generated_at'] as String),
    expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
    totalAmount: Money.fromCents(json['total_cents'] as int, currency: currency),
    breakdown: [
      for (final line in (json['breakdown'] as List).cast<Json>())
        SnapshotLineItem(
          externalRef: ExternalRef.listing(
            line['listing_id'] as String? ?? _orphanPrefix,
          ),
          category: PartyItemCategory.fromSlug(line['category'] as String),
          nameSnapshot: line['name'] as String,
          unitPriceSnapshot: Money.fromCents(
            line['unit_price_cents'] as int,
            currency: currency,
          ),
          quantity: Quantity(line['quantity'] as int),
          subtotal: Money.fromCents(
            line['subtotal_cents'] as int,
            currency: currency,
          ),
        ),
    ],
  );
}

String? _listingId(ExternalRef ref) {
  return ref.id.startsWith(_orphanPrefix) ? null : ref.id;
}
