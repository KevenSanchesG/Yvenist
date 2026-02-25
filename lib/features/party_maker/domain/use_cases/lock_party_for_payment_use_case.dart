import '../repositories/party_repository.dart';
import '../value_objects/party_id.dart';

class LockPartyForPaymentUseCase {
  final PartyRepository _repo;

  LockPartyForPaymentUseCase(this._repo);

  Future<void> call(PartyId partyId) async {
    final party = await _repo.getById(partyId);
    if (party == null) {
      throw Exception('Party não encontrada.');
    }

    party.lockForPayment();

    await _repo.save(party);
  }
}
