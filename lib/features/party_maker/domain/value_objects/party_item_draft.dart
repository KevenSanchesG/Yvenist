import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/pricing.dart';

/// O que o catálogo sabe de um anúncio (ou de um serviço próprio dele) no
/// momento em que a pessoa decide colocá-lo em uma festa.
///
/// Mantém o Party Maker independente do catálogo: quem chama traduz o anúncio
/// para este formato (`PartyItemCatalog`).
class PartyItemDraft {
  const PartyItemDraft({
    required this.externalRef,
    required this.category,
    required this.name,
    required this.pricing,
    this.imageUrl,
    this.description,
    this.capacity,
    this.isRequired = false,
    this.ownServices = const [],
    this.partners = const [],
  });

  final ExternalRef externalRef;
  final PartyItemCategory category;
  final String name;
  final Pricing pricing;
  final String? imageUrl;

  /// Uma frase sobre o item, quando o anunciante escreveu uma.
  final String? description;

  /// Quantas pessoas o espaço comporta, quando o anúncio informa.
  final int? capacity;

  /// Só para um serviço próprio: quem contrata o anúncio contrata este junto.
  final bool isRequired;

  /// O que o próprio anunciante oferece junto com este anúncio. Cada um só
  /// entra na festa ligado a ele.
  final List<PartyItemDraft> ownServices;

  /// Outros anúncios que este recomenda. Cada um é contratado à parte: aqui só
  /// vai o que um card mostra, e o resto é buscado quando a pessoa escolhe um.
  final List<PartyItemDraft> partners;
}
