import 'package:yvenist/features/vendor/domain/vendor_models.dart';

/// Um cadastro de fornecedor esperando análise, como a administração o vê.
class VendorReview {
  const VendorReview({
    required this.id,
    required this.legalName,
    required this.personType,
    required this.document,
    required this.createdAt,
  });

  final String id;
  final String legalName;
  final PersonType personType;

  /// CPF ou CNPJ completo, sem pontuação. Só a fila de análise o recebe.
  final String document;
  final DateTime createdAt;
}

/// Um anúncio esperando análise, junto com o cadastro de quem anuncia.
class ListingReview {
  const ListingReview({
    required this.id,
    required this.title,
    required this.categorySlug,
    required this.description,
    required this.city,
    required this.state,
    required this.priceFromCents,
    required this.createdAt,
    required this.vendorId,
    required this.vendorName,
    required this.vendorStatus,
    this.neighborhood,
    this.capacity,
    this.areaM2,
    this.amenities = const [],
    this.eventTypes = const [],
    this.cancellationPolicy = CancellationPolicy.flexible,
  });

  final String id;
  final String title;
  final String categorySlug;
  final String description;
  final String? neighborhood;
  final String city;
  final String state;
  final int priceFromCents;
  final int? capacity;
  final int? areaM2;
  final List<String> amenities;
  final List<String> eventTypes;
  final CancellationPolicy cancellationPolicy;
  final DateTime createdAt;

  final String vendorId;
  final String vendorName;
  final VendorStatus vendorStatus;

  /// O servidor só publica anúncio de fornecedor já aprovado.
  bool get canBePublished => vendorStatus == VendorStatus.approved;

  String get location => [?neighborhood, city, state].join(', ');

  /// O mesmo anúncio depois que a situação do fornecedor mudou.
  ListingReview withVendorStatus(VendorStatus status) {
    return ListingReview(
      id: id,
      title: title,
      categorySlug: categorySlug,
      description: description,
      neighborhood: neighborhood,
      city: city,
      state: state,
      priceFromCents: priceFromCents,
      capacity: capacity,
      areaM2: areaM2,
      amenities: amenities,
      eventTypes: eventTypes,
      cancellationPolicy: cancellationPolicy,
      createdAt: createdAt,
      vendorId: vendorId,
      vendorName: vendorName,
      vendorStatus: status,
    );
  }
}

/// O que está esperando análise agora, do mais antigo para o mais novo.
class ReviewQueue {
  const ReviewQueue({this.vendors = const [], this.listings = const []});

  final List<VendorReview> vendors;
  final List<ListingReview> listings;

  /// Os anúncios em análise de um fornecedor: é o que a aprovação do cadastro
  /// publica junto, e o que a recusa dele recusa junto.
  List<ListingReview> listingsOf(String vendorId) {
    return [
      for (final listing in listings)
        if (listing.vendorId == vendorId) listing,
    ];
  }
}
