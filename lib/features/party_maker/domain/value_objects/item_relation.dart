import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// O que um item é em relação a outro item da mesma festa.
enum ItemRelationKind {
  /// Um anúncio contratado por conta própria.
  independent('independent'),

  /// Serviço do próprio anúncio a que o item está ligado (o buffet do salão):
  /// sai da festa junto com ele.
  linked('linked'),

  /// Serviço do próprio anúncio que é obrigatório (uma taxa de limpeza): entra
  /// com ele e não sai sozinho.
  required('required'),

  /// Anúncio à parte, indicado por outro item: continua na festa sem ele.
  recommended('recommended');

  const ItemRelationKind(this.apiValue);

  final String apiValue;

  /// Um valor que o app ainda não conhece vira [independent]: o item é
  /// tratado sem privilégio nenhum.
  static ItemRelationKind fromApi(Object? value) {
    for (final kind in values) {
      if (kind.apiValue == value) return kind;
    }
    return independent;
  }
}

class ItemRelation {
  const ItemRelation.independent()
    : kind = ItemRelationKind.independent,
      parentId = null;

  const ItemRelation.linkedTo(PartyItemId parent)
    : kind = ItemRelationKind.linked,
      parentId = parent;

  const ItemRelation.requiredBy(PartyItemId parent)
    : kind = ItemRelationKind.required,
      parentId = parent;

  const ItemRelation.recommendedBy(PartyItemId parent)
    : kind = ItemRelationKind.recommended,
      parentId = parent;

  /// Reconstrói uma relação já gravada. Sem o item a que se liga, só pode
  /// ser independente.
  factory ItemRelation.restore(ItemRelationKind kind, PartyItemId? parentId) {
    if (parentId == null) return const ItemRelation.independent();
    return switch (kind) {
      ItemRelationKind.independent => const ItemRelation.independent(),
      ItemRelationKind.linked => ItemRelation.linkedTo(parentId),
      ItemRelationKind.required => ItemRelation.requiredBy(parentId),
      ItemRelationKind.recommended => ItemRelation.recommendedBy(parentId),
    };
  }

  final ItemRelationKind kind;

  /// O item da mesma festa a que este está ligado.
  final PartyItemId? parentId;

  /// Um serviço do próprio anunciante: só existe na festa junto com o anúncio.
  bool get isOwnService =>
      kind == ItemRelationKind.linked || kind == ItemRelationKind.required;

  bool get isRequired => kind == ItemRelationKind.required;

  @override
  bool operator ==(Object other) =>
      other is ItemRelation && other.kind == kind && other.parentId == parentId;

  @override
  int get hashCode => Object.hash(kind, parentId);

  @override
  String toString() => 'ItemRelation(${kind.apiValue}, $parentId)';
}
