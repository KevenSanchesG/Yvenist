import 'dart:async';

import 'package:yvenist/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

Listing buildListing({
  String id = 'listing-1',
  String title = 'Salão Glamour',
  String category = 'venue',
  int priceFromCents = 100000,
}) {
  return Listing(
    id: id,
    title: title,
    categorySlug: category,
    neighborhood: 'Campo Grande',
    city: 'Rio de Janeiro',
    state: 'RJ',
    priceFromCents: priceFromCents,
    coverImageUrl: 'https://example.com/capa.jpg',
    ratingAverage: 4.8,
    ratingCount: 12,
  );
}

/// Catálogo de demonstração que pode ser mandado falhar ou segurar a resposta,
/// para exercitar os estados de erro e de carregamento das telas.
class ControllableCatalog implements CatalogRepository {
  ControllableCatalog([InMemoryCatalogRepository? inner])
    : _inner = inner ?? InMemoryCatalogRepository();

  final InMemoryCatalogRepository _inner;

  /// Se definido, toda chamada falha com este erro.
  Object? failure;

  /// Se definido, só as buscas de anúncios falham.
  Object? searchFailure;

  /// Enquanto não for completado, as buscas ficam esperando.
  Completer<void>? gate;

  final List<ListingQuery> queries = [];
  final List<String?> cursors = [];

  void _failIfAsked(Object? specific) {
    final error = specific ?? failure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<List<CatalogCategory>> categories() async {
    _failIfAsked(null);
    return _inner.categories();
  }

  @override
  Future<List<EventType>> eventTypes() async {
    _failIfAsked(null);
    return _inner.eventTypes();
  }

  @override
  Future<ListingPage> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  }) async {
    queries.add(query);
    cursors.add(cursor);
    await gate?.future;
    _failIfAsked(searchFailure);
    return _inner.search(query, cursor: cursor, limit: limit);
  }
}
