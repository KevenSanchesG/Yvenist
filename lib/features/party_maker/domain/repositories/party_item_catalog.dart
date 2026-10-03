import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';

/// Por onde o Party Maker fica sabendo o que o catálogo diz de um anúncio.
///
/// O Party Maker não conhece o catálogo: declara aqui o que precisa, e quem
/// conhece os dois lados traduz (`ListingPartyItemCatalog`, em
/// `client/shared`).
abstract interface class PartyItemCatalog {
  /// O anúncio [listingId] como ele está no catálogo agora, com os serviços
  /// próprios e os parceiros, pronto para ser configurado.
  ///
  /// Lança `NotFoundFailure` se o anúncio saiu do catálogo.
  Future<PartyItemDraft> draftFor(String listingId);

  /// Os tipos de evento que uma festa pode ter, na ordem do catálogo.
  Future<List<EventTypeOption>> eventTypes();
}

/// Um tipo de evento: o `slug` que a festa guarda e o nome que a pessoa lê.
class EventTypeOption {
  const EventTypeOption({required this.slug, required this.name});

  final String slug;
  final String name;
}
