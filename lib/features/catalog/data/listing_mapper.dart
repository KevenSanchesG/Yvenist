import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Tradução entre o JSON da API e as entidades do catálogo.

/// Como a API descreve um preço: o modelo e o valor, que é nulo quando o
/// anúncio é sob consulta.
///
/// Os dois campos são lidos juntos para a regra valer nos dois sentidos: um
/// modelo desconhecido, ou um valor que não veio, é "sob consulta". Assim o app
/// nunca mostra um número que não sabe o que significa.
({PricingModel model, int? cents}) pricingFromJson(
  Object? model,
  Object? cents,
) {
  final parsed = PricingModel.fromApi(model);
  if (parsed == PricingModel.onRequest || cents is! int) {
    return (model: PricingModel.onRequest, cents: null);
  }
  return (model: parsed, cents: cents);
}

Listing listingFromJson(Json json) {
  final pricing = pricingFromJson(
    json['pricing_model'],
    json['price_from_cents'],
  );
  return Listing(
    id: json['id'] as String,
    title: json['title'] as String,
    categorySlug: json['category'] as String,
    neighborhood: json['neighborhood'] as String?,
    city: json['city'] as String,
    state: json['state'] as String,
    pricingModel: pricing.model,
    priceFromCents: pricing.cents,
    minimumPriceCents: pricing.cents == null
        ? null
        : json['minimum_price_cents'] as int?,
    currency: json['currency'] as String? ?? 'BRL',
    coverImageUrl: json['cover_image_url'] as String?,
    ratingAverage: (json['rating_average'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
  );
}

List<Listing> listingsFromJson(Object? items) {
  return (items as List).cast<Json>().map(listingFromJson).toList();
}

ListingOffer listingOfferFromJson(Json json) {
  final pricing = pricingFromJson(json['pricing_model'], json['price_cents']);
  return ListingOffer(
    id: json['id'] as String,
    categorySlug: json['category'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    pricingModel: pricing.model,
    priceCents: pricing.cents,
    minimumPriceCents: pricing.cents == null
        ? null
        : json['minimum_price_cents'] as int?,
    isRequired: json['required'] as bool? ?? false,
  );
}

ListingDetail listingDetailFromJson(Json json) {
  return ListingDetail(
    listing: listingFromJson(json),
    capacity: json['capacity'] as int?,
    offers: [
      for (final offer in (json['offers'] as List? ?? const []).cast<Json>())
        listingOfferFromJson(offer),
    ],
    partners: listingsFromJson(json['partners'] ?? const <Object>[]),
  );
}

CatalogCategory categoryFromJson(Json json) {
  return CatalogCategory(
    slug: json['slug'] as String,
    name: json['name'] as String,
    iconKey: json['icon'] as String? ?? 'other',
  );
}

EventType eventTypeFromJson(Json json) {
  return EventType(slug: json['slug'] as String, name: json['name'] as String);
}

extension ListingSortApi on ListingSort {
  /// Valor do parâmetro `sort` da API.
  String get apiValue => switch (this) {
    ListingSort.popular => 'popular',
    ListingSort.priceAsc => 'price_asc',
    ListingSort.priceDesc => 'price_desc',
    ListingSort.recent => 'recent',
  };
}
