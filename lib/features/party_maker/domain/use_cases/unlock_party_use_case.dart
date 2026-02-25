import '../repositories/party_repository.dart';
import '../value_objects/party_id.dart';

class UnlockPartyUseCase {
  final PartyRepository _repo;

  UnlockPartyUseCase(this._repo);

  Future<void> call(PartyId partyId) async {
    final party = await _repo.getById(partyId);
    if (party == null) {
      throw Exception('Party não encontrada.');
    }

    party.unlock();

    await _repo.save(party);
  }
}
