class ExternalRef {
  final String source; // ex: 'vendor_catalog'
  final String id;     // id externo do item/listing/serviço

  const ExternalRef({
    required this.source,
    required this.id,
  });

  @override
  bool operator ==(Object other) =>
      other is ExternalRef && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);

  @override
  String toString() => 'ExternalRef($source:$id)';
}
