import '../entities/party.dart';
import '../repositories/party_repository.dart';
import '../value_objects/party_id.dart';
import '../value_objects/party_title.dart';

class CreatePartyUseCase {
  final PartyRepository repository;

  CreatePartyUseCase(this.repository);

  Future<Party> call({
    required PartyId partyId,
    required String ownerId,
    required PartyTitle title,
  }) async {
    final now = DateTime.now();
    final party = Party(
      id: partyId,
      ownerId: ownerId,
      title: title,
      createdAt: now,
      updatedAt: now,
    );

    await repository.save(party);
    return party;
  }
}
