import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';

class CreatePartyUseCase {
  final PartyRepository repository;

  CreatePartyUseCase(this.repository);

  /// Cria a festa como rascunho ou, com [startPlanning], já em planejamento
  /// (uma gravação só, em vez de criar e depois iniciar).
  Future<Party> call({
    required PartyId partyId,
    required String ownerId,
    required PartyTitle title,
    bool startPlanning = false,
  }) async {
    final now = DateTime.now();
    final party = Party(
      id: partyId,
      ownerId: ownerId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    if (startPlanning) party.startPlanning();

    return repository.save(party);
  }
}
