import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

/// O que se sabe de um item do catálogo no momento em que o usuário decide
/// colocá-lo em uma festa.
///
/// Mantém o Party Maker independente do catálogo: quem chama (a vitrine, a
/// busca) traduz o seu anúncio para este formato.
class PartyItemDraft {
  const PartyItemDraft({
    required this.externalRef,
    required this.category,
    required this.name,
    required this.unitPrice,
    this.imageUrl,
  });

  final ExternalRef externalRef;
  final PartyItemCategory category;
  final String name;
  final Money unitPrice;
  final String? imageUrl;
}
