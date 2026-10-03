import 'package:yvenist/core/pricing/pricing_model.dart';

/// Um anúncio publicado, com o que a vitrine precisa mostrar.
class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.city,
    required this.state,
    required this.priceFromCents,
    this.pricingModel = PricingModel.fixed,
    this.minimumPriceCents,
    this.neighborhood,
    this.currency = 'BRL',
    this.coverImageUrl,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  }) : assert(
         (priceFromCents == null) == (pricingModel == PricingModel.onRequest),
         'Só um anúncio sob consulta fica sem preço.',
       );

  final String id;
  final String title;
  final String categorySlug;
  final String? neighborhood;
  final String city;
  final String state;

  /// A que o preço se refere: o serviço inteiro, cada pessoa, cada hora...
  final PricingModel pricingModel;

  /// Preço em centavos: dinheiro nunca em ponto flutuante. Nulo quando o
  /// anúncio é sob consulta.
  final int? priceFromCents;

  /// O menor valor cobrado, qualquer que seja a conta do modelo.
  final int? minimumPriceCents;
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

/// Um serviço que o próprio anunciante oferece junto com o anúncio: o buffet
/// do salão, a atração da casa, uma taxa de limpeza. Só pode ser contratado
/// com o anúncio a que pertence.
class ListingOffer {
  const ListingOffer({
    required this.id,
    required this.categorySlug,
    required this.name,
    required this.priceCents,
    this.pricingModel = PricingModel.fixed,
    this.minimumPriceCents,
    this.description,
    this.isRequired = false,
  }) : assert(
         (priceCents == null) == (pricingModel == PricingModel.onRequest),
         'Só um serviço sob consulta fica sem preço.',
       );

  final String id;
  final String categorySlug;
  final String name;
  final String? description;
  final PricingModel pricingModel;
  final int? priceCents;
  final int? minimumPriceCents;

  /// Quem contrata o anúncio contrata este serviço junto.
  final bool isRequired;
}

/// O anúncio com o que é preciso para colocá-lo em uma festa: a capacidade,
/// os serviços próprios e os parceiros que ele recomenda.
class ListingDetail {
  const ListingDetail({
    required this.listing,
    this.capacity,
    this.offers = const [],
    this.partners = const [],
  });

  final Listing listing;

  /// Quantas pessoas o espaço comporta, quando o anúncio informa.
  final int? capacity;
  final List<ListingOffer> offers;

  /// Outros anúncios publicados, de qualquer fornecedor. É uma indicação: cada
  /// um é contratado à parte.
  final List<Listing> partners;
}
