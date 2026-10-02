import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

class LockPartyForPaymentUseCase {
  final PartyRepository _repo;

  LockPartyForPaymentUseCase(this._repo);

  Future<Party> call(PartyId partyId) async {
    final party = await _repo.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.lockForPayment();

    return _repo.save(party);
  }
}
