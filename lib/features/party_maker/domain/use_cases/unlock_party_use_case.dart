import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

class UnlockPartyUseCase {
  final PartyRepository _repo;

  UnlockPartyUseCase(this._repo);

  Future<Party> call(PartyId partyId) async {
    final party = await _repo.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.unlock();

    return _repo.save(party);
  }
}
