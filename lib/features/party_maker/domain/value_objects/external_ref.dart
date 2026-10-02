class ExternalRef {
  /// Origem dos itens que vêm do catálogo de anúncios dos fornecedores.
  static const String vendorCatalog = 'vendor_catalog';

  final String source; // ex: 'vendor_catalog'
  final String id; // id externo do item/listing/serviço

  const ExternalRef({
    required this.source,
    required this.id,
  });

  /// Referência a um anúncio do catálogo.
  const ExternalRef.listing(String listingId)
      : this(source: vendorCatalog, id: listingId);

  @override
  bool operator ==(Object other) =>
      other is ExternalRef && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'ExternalRef($source:$id)';
}
