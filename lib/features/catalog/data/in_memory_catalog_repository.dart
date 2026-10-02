import 'package:yvenist/features/catalog/data/demo_catalog.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// Catálogo em memória: modo demonstração e testes. Reproduz o comportamento
/// da API (busca sem acentos, filtros, ordenação e paginação por cursor).
class InMemoryCatalogRepository implements CatalogRepository {
  InMemoryCatalogRepository({
    List<DemoListing>? listings,
    this.categoryList = demoCategories,
    this.eventTypeList = demoEventTypes,
  }) : _listings = listings ?? buildDemoListings();

  final List<DemoListing> _listings;
  final List<CatalogCategory> categoryList;
  final List<EventType> eventTypeList;

  @override
  Future<List<CatalogCategory>> categories() async => categoryList;

  @override
  Future<List<EventType>> eventTypes() async => eventTypeList;

  @override
  Future<ListingPage> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  }) async {
    final term = normalizeSearchText(query.text ?? '');
    final matches = _listings.where((entry) {
      final listing = entry.listing;
      if (query.categorySlug != null &&
          listing.categorySlug != query.categorySlug) {
        return false;
      }
      if (query.eventTypeSlug != null &&
          !entry.eventTypes.contains(query.eventTypeSlug)) {
        return false;
      }
      return term.isEmpty || _searchText(listing).contains(term);
    }).toList()..sort((a, b) => _compare(a, b, query.sort));

    // O cursor é simplesmente a posição do próximo item.
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + limit).clamp(0, matches.length);
    return ListingPage(
      items: [
        for (final entry in matches.sublist(start.clamp(0, end), end))
          entry.listing,
      ],
      nextCursor: end < matches.length ? '$end' : null,
    );
  }

  String _searchText(Listing listing) {
    final category = categoryList
        .where((c) => c.slug == listing.categorySlug)
        .map((c) => c.name)
        .join();
    return normalizeSearchText(
      '${listing.title} ${listing.neighborhood ?? ''} ${listing.city} '
      '${listing.state} $category',
    );
  }

  static int _compare(DemoListing a, DemoListing b, ListingSort sort) {
    final byKey = switch (sort) {
      ListingSort.popular => b.listing.ratingCount.compareTo(
        a.listing.ratingCount,
      ),
      ListingSort.priceAsc => a.listing.priceFromCents.compareTo(
        b.listing.priceFromCents,
      ),
      ListingSort.priceDesc => b.listing.priceFromCents.compareTo(
        a.listing.priceFromCents,
      ),
      ListingSort.recent => b.publishedOrder.compareTo(a.publishedOrder),
    };
    // Desempate por id: a ordem é sempre a mesma entre uma página e outra.
    return byKey != 0 ? byKey : a.listing.id.compareTo(b.listing.id);
  }
}

const Map<String, String> _accents = {
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Minúsculas, sem acentos e com espaços simples, como o backend faz.
String normalizeSearchText(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer
      .toString()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .join(' ');
}
