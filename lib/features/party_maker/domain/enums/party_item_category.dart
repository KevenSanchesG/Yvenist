/// Categoria de um item da festa. Os nomes são os mesmos slugs de categoria do
/// catálogo, então a conversão é direta.
enum PartyItemCategory {
  venue, // único por Party (invariante ativa no MVP)
  buffet,
  dj,
  decoration,
  security,
  staff,
  kids,
  attraction,
  beauty,
  other;

  /// Categoria correspondente ao slug do catálogo; desconhecidas viram [other].
  static PartyItemCategory fromSlug(String slug) {
    for (final category in values) {
      if (category.name == slug) return category;
    }
    return other;
  }
}
