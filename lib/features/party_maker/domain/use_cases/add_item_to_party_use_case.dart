import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/item_assembly.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/use_cases/create_party_use_case.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/configured_item.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Põe na festa um item já configurado, com os serviços próprios escolhidos.
///
/// Nada entra antes de a configuração passar pelas regras: se um campo
/// obrigatório falta, ou o item não cabe na festa, a festa fica como estava.
class AddItemToPartyUseCase {
  AddItemToPartyUseCase(this.repository, {required this.newId});

  final PartyRepository repository;

  /// Gera o id de cada item novo.
  final String Function() newId;

  /// Põe [selection] na festa [partyId] e devolve a festa como ficou gravada.
  ///
  /// Com [eventDetails], os dados do evento que a pessoa informou no mesmo
  /// formulário (a data e os convidados que o salão pede) são gravados junto.
  Future<Party> call({
    required PartyId partyId,
    required ConfiguredItem selection,
    EventDetails? eventDetails,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    return _addAndSave(party, selection, eventDetails);
  }

  /// Cria a festa já com o item, em uma gravação só: se o item não puder
  /// entrar, a festa não chega a existir.
  Future<Party> intoNewParty({
    required CreatePartyUseCase create,
    required PartyId partyId,
    required String ownerId,
    required EventDetails eventDetails,
    required ConfiguredItem selection,
  }) async {
    final party = create.newParty(
      partyId: partyId,
      ownerId: ownerId,
      details: eventDetails,
    );
    return _addAndSave(party, selection, null);
  }

  Future<Party> _addAndSave(
    Party party,
    ConfiguredItem selection,
    EventDetails? eventDetails,
  ) async {
    if (eventDetails != null) party.updateEventDetails(eventDetails);
    party.addItems(assembleItems(selection, newId: newId));
    return repository.save(party);
  }
}
