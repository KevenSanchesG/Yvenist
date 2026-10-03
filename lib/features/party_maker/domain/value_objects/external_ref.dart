/// De onde um item da festa veio: um anúncio do catálogo ou um serviço que o
/// próprio anunciante oferece junto com um anúncio.
class ExternalRef {
  /// Origem dos itens que vêm do catálogo de anúncios dos fornecedores.
  static const String vendorCatalog = 'vendor_catalog';

  /// Origem dos serviços próprios de um anúncio (o buffet do salão).
  static const String listingOffer = 'listing_offer';

  /// O que o item referenciava saiu do catálogo: ficou só a cópia.
  static const String unavailableSource = 'unavailable';

  final String source;
  final String id; // id externo do anúncio ou do serviço

  const ExternalRef({required this.source, required this.id});

  /// Referência a um anúncio do catálogo.
  const ExternalRef.listing(String listingId)
    : this(source: vendorCatalog, id: listingId);

  /// Referência a um serviço próprio de um anúncio.
  const ExternalRef.offer(String offerId)
    : this(source: listingOffer, id: offerId);

  /// Referência de um item cuja origem deixou de existir. O domínio precisa de
  /// uma referência para todo item; esta é única por item ([itemId]) e não
  /// aponta para nada do catálogo.
  const ExternalRef.unavailable(String itemId)
    : this(source: unavailableSource, id: itemId);

  bool get isListing => source == vendorCatalog;

  bool get isOffer => source == listingOffer;

  /// Falso quando o anúncio ou o serviço saiu do catálogo depois que o item
  /// entrou na festa.
  bool get isAvailable => source != unavailableSource;

  @override
  bool operator ==(Object other) =>
      other is ExternalRef && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'ExternalRef($source:$id)';
}
