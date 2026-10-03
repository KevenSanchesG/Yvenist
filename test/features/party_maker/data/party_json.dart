/// O JSON de uma festa e de um pedido de orçamento, do jeito que a API
/// responde (`PartyResponse` e `QuoteRequestResponse`), para os testes da
/// camada de dados.
library;

const String partyId = '11111111-2222-3333-4444-555555555555';
const String itemId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const String serviceId = 'bbbbbbbb-cccc-dddd-eeee-ffffffffffff';
const String listingId = '6d4c9d3f-0da9-4f27-9bb8-b158a61bdea5';
const String offerId = '7e5dae40-1eba-4038-8cc9-c269b72cefb6';
const String vendorId = '99999999-8888-7777-6666-555555555555';

Map<String, dynamic> quoteJson({
  String status = 'none',
  int? amountCents,
  String? message,
  String? respondedAt,
}) {
  return {
    'status': status,
    'amount_cents': amountCents,
    'message': message,
    'responded_at': respondedAt,
  };
}

Map<String, dynamic> itemJson({
  String id = itemId,
  String? listing = listingId,
  String? offer,
  String? parent,
  String relation = 'independent',
  String category = 'venue',
  String name = 'Salão Glamour 8',
  String pricingModel = 'fixed',
  int? unitPriceCents = 170000,
  int? minimumCents,
  int quantity = 1,
  Map<String, Object?> configuration = const {'duration_hours': 4},
  int? capacity = 120,
  Map<String, dynamic>? quote,
}) {
  return {
    'id': id,
    'listing_id': listing,
    'offer_id': offer,
    'vendor_id': vendorId,
    'parent_item_id': parent,
    'relation': relation,
    'category': category,
    'name': name,
    'pricing_model': pricingModel,
    'unit_price_cents': unitPriceCents,
    'minimum_cents': minimumCents,
    'currency': 'BRL',
    'quantity': quantity,
    'configuration': configuration,
    'capacity': capacity,
    'image_url': 'https://example.com/capa.jpg',
    'estimate_cents': unitPriceCents,
    'quote': quote ?? quoteJson(),
  };
}

Map<String, dynamic> historyJson({
  required String kind,
  String actor = 'client',
  int quoteRound = 1,
  String? itemId,
  String? itemName,
  String? message,
  int? amountCents,
  String createdAt = '2026-10-01T13:00:00Z',
}) {
  return {
    'kind': kind,
    'actor': actor,
    'quote_round': quoteRound,
    'item_id': itemId,
    'item_name': itemName,
    'message': message,
    'amount_cents': amountCents,
    'created_at': createdAt,
  };
}

Map<String, dynamic> partyJson({
  String id = partyId,
  String title = '15 anos da Maria',
  String status = 'planning',
  String? eventType,
  // Depois de 2026-01-15, o "agora" dos testes.
  String? eventAt = '2026-12-25T22:00:00Z',
  int? guestCount = 80,
  int quoteRound = 0,
  int version = 1,
  List<Map<String, dynamic>>? items,
  Map<String, dynamic>? snapshot,
  List<Map<String, dynamic>> history = const [],
}) {
  return {
    'id': id,
    'owner_id': 'user-1',
    'title': title,
    'event_type': eventType,
    'event_at': eventAt,
    'guest_count': guestCount,
    'status': status,
    'quote_round': quoteRound,
    'version': version,
    'items': items ?? [itemJson()],
    'estimate_cents': 170000,
    'unpriced_items': 0,
    'quoted_cents': null,
    'currency': 'BRL',
    'snapshot': snapshot,
    'history': history,
    'created_at': '2026-10-01T12:00:00Z',
    'updated_at': '2026-10-01T12:30:00Z',
  };
}

/// Um pedido de orçamento como o fornecedor o recebe.
Map<String, dynamic> quoteRequestJson({
  String item = itemId,
  String party = partyId,
  String partyStatus = 'locked',
  int quoteRound = 1,
  String relation = 'independent',
  String? parentName,
  String category = 'venue',
  String name = 'Salão Glamour 8',
  String pricingModel = 'fixed',
  int? unitPriceCents = 170000,
  int? estimateCents = 170000,
  Map<String, Object?> configuration = const {'duration_hours': 4},
  Map<String, dynamic>? quote,
}) {
  return {
    'item_id': item,
    'party_id': party,
    'party_status': partyStatus,
    'quote_round': quoteRound,
    'updated_at': '2026-10-01T13:00:00Z',
    'event_type': 'wedding',
    'event_at': '2026-12-25T22:00:00Z',
    'guest_count': 80,
    'listing_id': listingId,
    'offer_id': null,
    'relation': relation,
    'parent_name': parentName,
    'category': category,
    'name': name,
    'pricing_model': pricingModel,
    'unit_price_cents': unitPriceCents,
    'minimum_cents': null,
    'currency': 'BRL',
    'quantity': 1,
    'configuration': configuration,
    'estimate_cents': estimateCents,
    'quote': quote ?? quoteJson(status: 'pending'),
    'can_respond': partyStatus == 'locked',
  };
}
