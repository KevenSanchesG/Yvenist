/// Categoria de anúncio (salão, atração, buffet...).
class CatalogCategory {
  const CatalogCategory({
    required this.slug,
    required this.name,
    required this.iconKey,
  });

  final String slug;
  final String name;

  /// Chave que a apresentação traduz para um ícone.
  final String iconKey;

  @override
  bool operator ==(Object other) =>
      other is CatalogCategory && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

/// Ocasião atendida por um anúncio (casamento, 15 anos...).
class EventType {
  const EventType({required this.slug, required this.name});

  final String slug;
  final String name;

  @override
  bool operator ==(Object other) => other is EventType && other.slug == slug;

  @override
  int get hashCode => slug.hashCode;
}

enum ListingSort { popular, priceAsc, priceDesc, recent }

/// O que o usuário está procurando no catálogo.
class ListingQuery {
  const ListingQuery({
    this.text,
    this.categorySlug,
    this.eventTypeSlug,
    this.sort = ListingSort.popular,
  });

  final String? text;
  final String? categorySlug;
  final String? eventTypeSlug;
  final ListingSort sort;

  ListingQuery copyWith({
    String? Function()? text,
    String? Function()? categorySlug,
    String? Function()? eventTypeSlug,
    ListingSort? sort,
  }) {
    return ListingQuery(
      text: text != null ? text() : this.text,
      categorySlug: categorySlug != null ? categorySlug() : this.categorySlug,
      eventTypeSlug: eventTypeSlug != null
          ? eventTypeSlug()
          : this.eventTypeSlug,
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ListingQuery &&
      other.text == text &&
      other.categorySlug == categorySlug &&
      other.eventTypeSlug == eventTypeSlug &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(text, categorySlug, eventTypeSlug, sort);
}
