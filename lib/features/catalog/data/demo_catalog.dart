import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Dados do modo demonstração: os mesmos anúncios de exemplo que o protótipo
/// mostrava, agora atrás do contrato do catálogo. O comando `seed-demo` do
/// backend cria anúncios equivalentes.

const List<CatalogCategory> demoCategories = [
  CatalogCategory(slug: 'venue', name: 'Salões', iconKey: 'venue'),
  CatalogCategory(slug: 'attraction', name: 'Atrações', iconKey: 'attraction'),
  CatalogCategory(slug: 'kids', name: 'Brinquedos', iconKey: 'kids'),
  CatalogCategory(slug: 'buffet', name: 'Buffet e Bar', iconKey: 'buffet'),
  CatalogCategory(slug: 'decoration', name: 'Decorações', iconKey: 'decoration'),
  CatalogCategory(slug: 'beauty', name: 'Beleza', iconKey: 'beauty'),
  CatalogCategory(slug: 'dj', name: 'DJ e Som', iconKey: 'dj'),
  CatalogCategory(slug: 'staff', name: 'Equipe', iconKey: 'staff'),
  CatalogCategory(slug: 'security', name: 'Segurança', iconKey: 'security'),
  CatalogCategory(slug: 'other', name: 'Outros', iconKey: 'other'),
];

const List<EventType> demoEventTypes = [
  EventType(slug: 'wedding', name: 'Casamentos'),
  EventType(slug: 'debutante', name: '15 anos'),
  EventType(slug: 'kids_party', name: 'Infantil'),
  EventType(slug: 'corporate', name: 'Corporativo'),
  EventType(slug: 'barbecue', name: 'Churrasco'),
  EventType(slug: 'graduation', name: 'Formatura'),
];

const String _venueImage =
    'https://images.unsplash.com/photo-1519167758481-83f550bb49b3'
    '?auto=format&fit=crop&w=600&q=80';
const String _attractionImage =
    'https://images.unsplash.com/photo-1523438885200-e635ba2c371e'
    '?auto=format&fit=crop&w=600&q=80';

/// Um anúncio de demonstração e os tipos de evento que ele atende.
class DemoListing {
  const DemoListing(this.listing, this.eventTypes, {required this.publishedOrder});

  final Listing listing;
  final Set<String> eventTypes;

  /// Quanto maior, mais recente.
  final int publishedOrder;
}

List<DemoListing> buildDemoListings() {
  const groups = [
    (
      slug: 'venue',
      title: 'Salão Glamour',
      neighborhood: 'Campo Grande',
      basePrice: 100000,
      step: 10000,
      rating: 5.0,
      reviews: 120,
      image: _venueImage,
      events: {'wedding', 'debutante', 'graduation'},
    ),
    (
      slug: 'attraction',
      title: 'Atração Festiva',
      neighborhood: 'Barra da Tijuca',
      basePrice: 80000,
      step: 5000,
      rating: 4.8,
      reviews: 85,
      image: _attractionImage,
      events: {'kids_party', 'corporate'},
    ),
    (
      slug: 'buffet',
      title: 'Buffet Sabor & Festa',
      neighborhood: 'Tijuca',
      basePrice: 250000,
      step: 15000,
      rating: 4.7,
      reviews: 60,
      image: _venueImage,
      events: {'wedding', 'corporate', 'barbecue'},
    ),
    (
      slug: 'decoration',
      title: 'Decoração Encanto',
      neighborhood: 'Recreio',
      basePrice: 60000,
      step: 4000,
      rating: 4.9,
      reviews: 40,
      image: _attractionImage,
      events: {'wedding', 'debutante', 'kids_party'},
    ),
  ];

  final listings = <DemoListing>[];
  var order = groups.length * 8;
  for (final group in groups) {
    for (var index = 0; index < 8; index++) {
      listings.add(
        DemoListing(
          Listing(
            id: 'demo-${group.slug}-${index + 1}',
            title: '${group.title} ${index + 1}',
            categorySlug: group.slug,
            neighborhood: group.neighborhood,
            city: 'Rio de Janeiro',
            state: 'RJ',
            priceFromCents: group.basePrice + index * group.step,
            coverImageUrl: group.image,
            ratingAverage: group.rating,
            ratingCount: group.reviews + index,
          ),
          group.events,
          publishedOrder: order--,
        ),
      );
    }
  }
  return listings;
}
