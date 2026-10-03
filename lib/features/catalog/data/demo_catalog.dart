import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Dados do modo demonstração: os anúncios de exemplo, atrás do contrato do
/// catálogo. O comando `seed-demo` do backend cria anúncios equivalentes
/// (`backend/app/cli.py`): mudou um lado, mude o outro.

const List<CatalogCategory> demoCategories = [
  CatalogCategory(slug: 'venue', name: 'Salões', iconKey: 'venue'),
  CatalogCategory(slug: 'attraction', name: 'Atrações', iconKey: 'attraction'),
  CatalogCategory(slug: 'kids', name: 'Brinquedos', iconKey: 'kids'),
  CatalogCategory(slug: 'buffet', name: 'Buffet e Bar', iconKey: 'buffet'),
  CatalogCategory(
    slug: 'decoration',
    name: 'Decorações',
    iconKey: 'decoration',
  ),
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

const int _listingsPerGroup = 8;

/// A última decoração é sob consulta: mostra como fica um item sem preço
/// publicado.
const String _onRequestListingId = 'demo-decoration-$_listingsPerGroup';

/// O que cada salão recomenda: a decoração e a atração de mesmo número.
const List<String> _venuePartnerCategories = ['decoration', 'attraction'];

/// Um anúncio de demonstração e o que o catálogo sabe dele além do card.
class DemoListing {
  const DemoListing(
    this.listing,
    this.eventTypes, {
    required this.publishedOrder,
    this.capacity,
    this.offers = const [],
    this.partnerIds = const [],
  });

  final Listing listing;
  final Set<String> eventTypes;

  /// Quanto maior, mais recente.
  final int publishedOrder;
  final int? capacity;
  final List<ListingOffer> offers;
  final List<String> partnerIds;
}

/// Os serviços que cada salão de demonstração oferece junto com o espaço.
List<ListingOffer> _venueOffers(String listingId) {
  return [
    ListingOffer(
      id: '$listingId-offer-buffet',
      categorySlug: 'buffet',
      name: 'Buffet do salão',
      description: 'Almoço ou jantar servido pela equipe da casa.',
      pricingModel: PricingModel.perPerson,
      priceCents: 4500,
    ),
    ListingOffer(
      id: '$listingId-offer-animation',
      categorySlug: 'attraction',
      name: 'Animação da casa',
      description: 'Recreadores do próprio salão.',
      pricingModel: PricingModel.perHour,
      priceCents: 18000,
    ),
    ListingOffer(
      id: '$listingId-offer-cleaning',
      categorySlug: 'other',
      name: 'Taxa de limpeza',
      description: 'Cobrada em toda locação.',
      priceCents: 15000,
      isRequired: true,
    ),
  ];
}

List<DemoListing> buildDemoListings() {
  const groups = [
    (
      slug: 'venue',
      title: 'Salão Glamour',
      neighborhood: 'Campo Grande',
      model: PricingModel.fixed,
      basePrice: 100000,
      step: 10000,
      minimum: null,
      rating: 5.0,
      reviews: 120,
      image: _venueImage,
      events: {'wedding', 'debutante', 'graduation'},
    ),
    (
      slug: 'attraction',
      title: 'Atração Festiva',
      neighborhood: 'Barra da Tijuca',
      model: PricingModel.perHour,
      basePrice: 20000,
      step: 1000,
      minimum: null,
      rating: 4.8,
      reviews: 85,
      image: _attractionImage,
      events: {'kids_party', 'corporate'},
    ),
    (
      slug: 'buffet',
      title: 'Buffet Sabor & Festa',
      neighborhood: 'Tijuca',
      model: PricingModel.perPerson,
      basePrice: 5500,
      step: 500,
      minimum: 250000,
      rating: 4.7,
      reviews: 60,
      image: _venueImage,
      events: {'wedding', 'corporate', 'barbecue'},
    ),
    (
      slug: 'decoration',
      title: 'Decoração Encanto',
      neighborhood: 'Recreio',
      model: PricingModel.fixed,
      basePrice: 60000,
      step: 4000,
      minimum: null,
      rating: 4.9,
      reviews: 40,
      image: _attractionImage,
      events: {'wedding', 'debutante', 'kids_party'},
    ),
  ];

  final listings = <DemoListing>[];
  var order = groups.length * _listingsPerGroup;
  for (final group in groups) {
    for (var index = 0; index < _listingsPerGroup; index++) {
      final number = index + 1;
      final id = 'demo-${group.slug}-$number';
      final isVenue = group.slug == 'venue';
      final isOnRequest = id == _onRequestListingId;

      listings.add(
        DemoListing(
          Listing(
            id: id,
            title: '${group.title} $number',
            categorySlug: group.slug,
            neighborhood: group.neighborhood,
            city: 'Rio de Janeiro',
            state: 'RJ',
            pricingModel: isOnRequest ? PricingModel.onRequest : group.model,
            priceFromCents: isOnRequest
                ? null
                : group.basePrice + index * group.step,
            minimumPriceCents: isOnRequest ? null : group.minimum,
            coverImageUrl: group.image,
            ratingAverage: group.rating,
            ratingCount: group.reviews + index,
          ),
          group.events,
          publishedOrder: order--,
          capacity: isVenue ? 100 + index * 20 : null,
          offers: isVenue ? _venueOffers(id) : const [],
          partnerIds: isVenue
              ? [
                  for (final category in _venuePartnerCategories)
                    'demo-$category-$number',
                ]
              : const [],
        ),
      );
    }
  }
  return listings;
}
