import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_configuration.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Fábricas de objetos de domínio usadas pelos testes do Party Maker.

/// O "agora" dos testes: as regras que dependem do relógio (a data da festa
/// precisa ser no futuro) ficam com um resultado só.
final DateTime kFixedNow = DateTime(2026, 1, 15, 12);

/// Uma data de festa no futuro de [kFixedNow].
final DateTime kEventDay = DateTime(2026, 12, 25, 19);

/// A duração que os itens cobrados por hora e os salões pedem.
const Map<String, Object> kFourHours = {ItemConfiguration.durationKey: 4};

/// Relógio de teste: parado em [now] até alguém adiantar.
class TestClock {
  TestClock([DateTime? start]) : now = start ?? kFixedNow;

  DateTime now;

  DateTime call() => now;

  void advance(Duration by) => now = now.add(by);
}

DateTime fixedClock() => kFixedNow;

Party buildParty({
  String id = 'party-1',
  String ownerId = 'user-1',
  String title = 'Aniversário da Ana',
  DateTime Function() clock = fixedClock,
}) {
  return Party(
    id: PartyId(id),
    ownerId: ownerId,
    title: PartyTitle(title),
    createdAt: kFixedNow,
    updatedAt: kFixedNow,
    clock: clock,
  );
}

EventDetails buildDetails({
  String title = 'Aniversário da Ana',
  String? eventType,
  DateTime? eventDate,
  int? guests,
}) {
  return EventDetails(
    title: PartyTitle(title),
    eventType: eventType,
    eventDate: eventDate == null ? null : EventDate(eventDate),
    guestCount: guests == null ? null : GuestCount(guests),
  );
}

/// Uma festa em planejamento, com a data e os convidados informados e os
/// [items] já dentro: pronta para ter o orçamento solicitado.
Party planningParty({
  List<PartyItem>? items,
  DateTime? eventDate,
  int? guests = 80,
  bool withEventDate = true,
  DateTime Function() clock = fixedClock,
}) {
  final party = buildParty(clock: clock)
    ..startPlanning()
    ..updateEventDetails(
      buildDetails(
        eventDate: withEventDate ? eventDate ?? kEventDay : null,
        guests: guests,
      ),
    );
  final toAdd = items ?? [buildItem()];
  if (toAdd.isNotEmpty) party.addItems(toAdd);
  return party;
}

Pricing buildPricing({
  PricingModel model = PricingModel.fixed,
  int? cents = 80000,
  int? minimumCents,
  String currency = 'BRL',
}) {
  return Pricing(
    model: model,
    amount: cents == null ? null : Money.fromCents(cents, currency: currency),
    minimum: minimumCents == null
        ? null
        : Money.fromCents(minimumCents, currency: currency),
    currency: currency,
  );
}

/// Um item de festa. O padrão é o mais simples que existe: um produto de
/// preço fixo, sem campo obrigatório.
PartyItem buildItem({
  String id = 'item-1',
  String externalId = 'listing-1',
  ExternalRef? ref,
  PartyItemCategory category = PartyItemCategory.other,
  String name = 'Kit de copos',
  PricingModel model = PricingModel.fixed,
  int? priceCents = 80000,
  int? minimumCents,
  String currency = 'BRL',
  int quantity = 1,
  Map<String, Object> configuration = const {},
  ItemRelation relation = const ItemRelation.independent(),
  ItemQuote quote = const ItemQuote.none(),
  int? capacity,
}) {
  return PartyItem(
    id: PartyItemId(id),
    externalRef: ref ?? ExternalRef.listing(externalId),
    category: category,
    nameSnapshot: name,
    pricing: buildPricing(
      model: model,
      cents: priceCents,
      minimumCents: minimumCents,
      currency: currency,
    ),
    quantity: Quantity(quantity),
    configuration: ItemConfiguration(configuration),
    relation: relation,
    quote: quote,
    capacity: capacity,
  );
}

/// Um salão já configurado (com a duração, que é obrigatória).
PartyItem buildVenue({
  String id = 'venue-1',
  String externalId = 'listing-venue',
  String name = 'Salão Glamour',
  int priceCents = 170000,
  int? capacity = 120,
}) {
  return buildItem(
    id: id,
    externalId: externalId,
    category: PartyItemCategory.venue,
    name: name,
    priceCents: priceCents,
    configuration: kFourHours,
    capacity: capacity,
  );
}

/// Um serviço do próprio anúncio [parentId], ligado a ele.
PartyItem buildOwnService({
  String id = 'service-1',
  String offerId = 'offer-1',
  ExternalRef? ref,
  String parentId = 'venue-1',
  String name = 'Buffet do salão',
  PartyItemCategory category = PartyItemCategory.buffet,
  PricingModel model = PricingModel.perPerson,
  int? priceCents = 4500,
  bool isRequired = false,
  Map<String, Object> configuration = const {},
}) {
  final parent = PartyItemId(parentId);
  return buildItem(
    id: id,
    ref: ref ?? ExternalRef.offer(offerId),
    category: category,
    name: name,
    model: model,
    priceCents: priceCents,
    configuration: configuration,
    relation: isRequired
        ? ItemRelation.requiredBy(parent)
        : ItemRelation.linkedTo(parent),
  );
}

/// O que o catálogo diz de um anúncio (ou de um serviço dele).
PartyItemDraft buildDraft({
  String externalId = 'listing-1',
  ExternalRef? ref,
  PartyItemCategory category = PartyItemCategory.other,
  String name = 'Kit de copos',
  PricingModel model = PricingModel.fixed,
  int? priceCents = 80000,
  int? minimumCents,
  int? capacity,
  bool isRequired = false,
  List<PartyItemDraft> ownServices = const [],
  List<PartyItemDraft> partners = const [],
}) {
  return PartyItemDraft(
    externalRef: ref ?? ExternalRef.listing(externalId),
    category: category,
    name: name,
    pricing: buildPricing(
      model: model,
      cents: priceCents,
      minimumCents: minimumCents,
    ),
    capacity: capacity,
    isRequired: isRequired,
    ownServices: ownServices,
    partners: partners,
  );
}

/// O anúncio do jeito que a pessoa o configurou, pronto para entrar na festa.
ConfiguredItem buildSelection({
  PartyItemDraft? draft,
  int quantity = 1,
  Map<String, Object?> configuration = const {},
  List<ConfiguredItem> ownServices = const [],
  String? recommendedBy,
}) {
  return ConfiguredItem(
    draft: draft ?? buildDraft(),
    quantity: quantity,
    configuration: configuration,
    ownServices: ownServices,
    recommendedBy: recommendedBy == null ? null : PartyItemId(recommendedBy),
  );
}

/// Gera ids previsíveis: `item-1`, `item-2`...
String Function() sequentialIds([String prefix = 'item']) {
  var next = 0;
  return () => '$prefix-${++next}';
}
