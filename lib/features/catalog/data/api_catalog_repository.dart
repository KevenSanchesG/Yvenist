import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/catalog/data/listing_mapper.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// Catálogo servido pela API do Yvenist.
class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api);

  final ApiClient _api;

  // Categorias e tipos de evento quase nunca mudam: uma busca por execução do
  // app basta. Só o resultado bem-sucedido é guardado; se falhar, a próxima
  // chamada tenta de novo.
  List<CatalogCategory>? _categories;
  List<EventType>? _eventTypes;

  @override
  Future<List<CatalogCategory>> categories() async {
    final cached = _categories;
    if (cached != null) return cached;

    final json = await _api.get('/catalog/categories') as List;
    return _categories =
        json.cast<Json>().map(categoryFromJson).toList(growable: false);
  }

  @override
  Future<List<EventType>> eventTypes() async {
    final cached = _eventTypes;
    if (cached != null) return cached;

    final json = await _api.get('/catalog/event-types') as List;
    return _eventTypes =
        json.cast<Json>().map(eventTypeFromJson).toList(growable: false);
  }

  @override
  Future<ListingPage> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  }) async {
    final json = await _api.get(
      '/catalog/listings',
      query: {
        'q': query.text?.trim(),
        'category': query.categorySlug,
        'event_type': query.eventTypeSlug,
        'sort': query.sort.apiValue,
        'limit': '$limit',
        'cursor': cursor,
      },
    ) as Json;

    return ListingPage(
      items: listingsFromJson(json['items']),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}
