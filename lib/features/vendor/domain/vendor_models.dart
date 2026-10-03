import 'package:yvenist/core/pricing/pricing_model.dart';

/// Situação do cadastro de fornecedor de uma conta.
enum VendorStatus {
  /// A conta ainda não pediu para ser fornecedora.
  none,
  pendingReview,
  approved,
  rejected,
}

enum PersonType { individual, company }

enum CancellationPolicy { flexible, moderate }

enum VendorListingStatus { draft, pendingReview, published, rejected, archived }

/// Cadastro de fornecedor como a conta o enxerga.
class VendorProfile {
  const VendorProfile({
    required this.status,
    required this.legalName,
    required this.documentMasked,
    this.rejectionReason,
  });

  final VendorStatus status;
  final String legalName;

  /// CPF/CNPJ com o miolo escondido. O número completo nunca volta ao app.
  final String documentMasked;
  final String? rejectionReason;
}

/// Um anúncio do próprio fornecedor, em qualquer situação.
class VendorListing {
  const VendorListing({
    required this.id,
    required this.title,
    required this.status,
    this.rejectionReason,
  });

  final String id;
  final String title;
  final VendorListingStatus status;
  final String? rejectionReason;
}

/// Um serviço que o próprio espaço oferece junto com a locação (o buffet da
/// casa, uma taxa de limpeza), como o fornecedor o cadastra.
class OfferDraft {
  const OfferDraft({
    required this.categorySlug,
    required this.name,
    required this.priceCents,
    this.pricingModel = PricingModel.fixed,
    this.isRequired = false,
  }) : assert(
         (priceCents == null) == (pricingModel == PricingModel.onRequest),
         'Só um serviço sob consulta fica sem preço.',
       );

  final String categorySlug;
  final String name;
  final PricingModel pricingModel;

  /// Nulo quando o serviço é sob consulta.
  final int? priceCents;

  /// Quem aluga o espaço contrata este serviço junto.
  final bool isRequired;
}

/// Tudo que o fluxo "anunciar um salão" coleta, pronto para envio.
class HallListingDraft {
  const HallListingDraft({
    required this.personType,
    required this.document,
    required this.legalName,
    required this.title,
    required this.description,
    required this.city,
    required this.state,
    required this.priceFromCents,
    this.pricingModel = PricingModel.fixed,
    this.minimumPriceCents,
    this.offers = const [],
    this.neighborhood,
    this.areaM2,
    this.capacity,
    this.eventTypes = const {},
    this.amenities = const {},
    this.cancellationPolicy = CancellationPolicy.flexible,
  }) : assert(
         (priceFromCents == null) == (pricingModel == PricingModel.onRequest),
         'Só um anúncio sob consulta fica sem preço.',
       );

  final PersonType personType;
  final String document;
  final String legalName;
  final String title;
  final String description;
  final String? neighborhood;
  final String city;
  final String state;

  /// A que o preço se refere: a locação inteira, cada convidado, cada hora.
  final PricingModel pricingModel;

  /// Nulo quando o anúncio é sob consulta.
  final int? priceFromCents;
  final int? minimumPriceCents;
  final List<OfferDraft> offers;
  final int? areaM2;
  final int? capacity;
  final Set<String> eventTypes;
  final Set<String> amenities;
  final CancellationPolicy cancellationPolicy;
}

/// Unidades da federação, para o campo "UF".
const List<String> brazilianStates = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
];
