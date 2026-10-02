import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Tradução entre o JSON da API e as entidades do catálogo.

Listing listingFromJson(Json json) {
  return Listing(
    id: json['id'] as String,
    title: json['title'] as String,
    categorySlug: json['category'] as String,
    neighborhood: json['neighborhood'] as String?,
    city: json['city'] as String,
    state: json['state'] as String,
    priceFromCents: json['price_from_cents'] as int,
    currency: json['currency'] as String? ?? 'BRL',
    coverImageUrl: json['cover_image_url'] as String?,
    ratingAverage: (json['rating_average'] as num?)?.toDouble() ?? 0,
    ratingCount: json['rating_count'] as int? ?? 0,
  );
}

List<Listing> listingsFromJson(Object? items) {
  return (items as List).cast<Json>().map(listingFromJson).toList();
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
