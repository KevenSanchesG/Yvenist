/// Um anúncio publicado, com o que a vitrine precisa mostrar.
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.city,
    required this.state,
    required this.priceFromCents,
    this.neighborhood,
    this.currency = 'BRL',
    this.coverImageUrl,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String title;
  final String categorySlug;
  final String? neighborhood;
  final String city;
  final String state;

  /// Preço inicial em centavos: dinheiro nunca em ponto flutuante.
  final int priceFromCents;
  final String currency;
  final String? coverImageUrl;
  final double ratingAverage;
  final int ratingCount;

  /// "Campo Grande, RJ" quando há bairro; senão "Rio de Janeiro, RJ".
  String get locationLabel => '${neighborhood ?? city}, $state';

  bool get hasRatings => ratingCount > 0;

  @override
  bool operator ==(Object other) => other is Listing && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Listing($id, $title)';
}
