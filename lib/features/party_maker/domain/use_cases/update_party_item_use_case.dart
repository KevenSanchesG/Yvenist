import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_assembly.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

/// Altera a configuração de um item que já está na festa.
///
/// O que foi copiado do catálogo (nome, preço) continua como entrou; muda só o
/// que a pessoa informa. A festa é validada e recalculada de novo.
class UpdatePartyItemUseCase {
  UpdatePartyItemUseCase(this.repository, {required this.newId});

  final PartyRepository repository;
  final String Function() newId;

  /// [ownServices], quando informado, é a escolha completa dos serviços
  /// próprios do item: os que não estavam entram, os que saíram da escolha
  /// saem (menos os obrigatórios), e os que ficaram têm a configuração
  /// atualizada. Nulo, os serviços próprios não são tocados.
  Future<Party> call({
    required PartyId partyId,
    required PartyItemId itemId,
    required int quantity,
    required Map<String, Object?> configuration,
    List<ConfiguredItem>? ownServices,
    EventDetails? eventDetails,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    if (eventDetails != null) party.updateEventDetails(eventDetails);
    party.updateItem(
      itemId,
      quantity: Quantity(quantity),
      configuration: configuration,
    );
    if (ownServices != null) _syncOwnServices(party, itemId, ownServices);

    return repository.save(party);
  }

  void _syncOwnServices(
    Party party,
    PartyItemId parentId,
    List<ConfiguredItem> chosen,
  ) {
    final current = {
      for (final child in party.budget.childrenOf(parentId))
        if (child.relation.isOwnService) child.externalRef: child,
    };
    final wanted = {for (final service in chosen) service.draft.externalRef};

    for (final child in current.values) {
      // Um serviço obrigatório não sai sozinho: fica, mesmo fora da escolha. E
      // um serviço que saiu do catálogo não aparece na escolha: só sai quando
      // a pessoa o remove, sabendo o que está tirando.
      if (child.externalRef.isOffer &&
          !wanted.contains(child.externalRef) &&
          child.relation.kind == ItemRelationKind.linked) {
        party.removeItem(child.id);
      }
    }
    for (final service in chosen) {
      final existing = current[service.draft.externalRef];
      if (existing == null) {
        party.addItems([
          assembleOwnService(service, parentId: parentId, newId: newId),
        ]);
      } else {
        party.updateItem(
          existing.id,
          quantity: Quantity(service.quantity),
          configuration: service.configuration,
        );
      }
    }
  }
}
