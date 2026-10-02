import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Uma página de resultados. [nextCursor] nulo significa que acabou.
class ListingPage {
  const ListingPage({required this.items, this.nextCursor});

  final List<Listing> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// Catálogo público de anúncios. Não exige autenticação.
abstract interface class CatalogRepository {
  Future<List<CatalogCategory>> categories();

  Future<List<EventType>> eventTypes();

  /// Busca paginada por cursor: passe o [ListingPage.nextCursor] da página
  /// anterior em [cursor] para continuar de onde parou.
  Future<ListingPage> search(
    ListingQuery query, {
    String? cursor,
    int limit = 20,
  });
}
