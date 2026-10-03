import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_configuration_spec.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Monta os itens da festa a partir do que a pessoa configurou.
///
/// É aqui que a configuração crua do formulário passa pelas regras da
/// categoria: o que sai já está validado e limpo.

/// O item de [selection] e, depois dele, os serviços próprios escolhidos.
///
/// Lança [RequiredItemMissing] se um serviço obrigatório do anúncio ficou de
/// fora, e [InvalidItemConfiguration] ou [InvalidQuantity] se algo do que foi
/// preenchido não passa.
List<PartyItem> assembleItems(
  ConfiguredItem selection, {
  required String Function() newId,
}) {
  final chosen = {
    for (final service in selection.ownServices) service.draft.externalRef,
  };
  for (final service in selection.draft.ownServices) {
    if (service.isRequired && !chosen.contains(service.externalRef)) {
      throw const RequiredItemMissing();
    }
  }

  final recommendedBy = selection.recommendedBy;
  final item = _assemble(
    selection,
    id: PartyItemId(newId()),
    relation: recommendedBy == null
        ? const ItemRelation.independent()
        : ItemRelation.recommendedBy(recommendedBy),
  );
  return [
    item,
    for (final service in selection.ownServices)
      assembleOwnService(service, parentId: item.id, newId: newId),
  ];
}

/// Um serviço próprio do item [parentId], ligado a ele.
PartyItem assembleOwnService(
  ConfiguredItem service, {
  required PartyItemId parentId,
  required String Function() newId,
}) {
  return _assemble(
    service,
    id: PartyItemId(newId()),
    relation: service.draft.isRequired
        ? ItemRelation.requiredBy(parentId)
        : ItemRelation.linkedTo(parentId),
  );
}

PartyItem _assemble(
  ConfiguredItem selection, {
  required PartyItemId id,
  required ItemRelation relation,
}) {
  final draft = selection.draft;
  final spec = ItemConfigurationSpec.of(
    category: draft.category,
    pricingModel: draft.pricing.model,
    isOwnService: relation.isOwnService,
  );
  final quantity = Quantity(selection.quantity);
  spec.checkQuantity(quantity);

  return PartyItem(
    id: id,
    externalRef: draft.externalRef,
    category: draft.category,
    nameSnapshot: draft.name,
    pricing: draft.pricing,
    quantity: quantity,
    configuration: spec.validate(selection.configuration),
    relation: relation,
    imageUrlSnapshot: draft.imageUrl,
    capacity: draft.capacity,
  );
}
