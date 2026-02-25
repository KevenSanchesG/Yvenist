import '../repositories/party_repository.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/cancellation_result.dart';
import '../value_objects/party_id.dart';

class CancelPartyUseCase {
  final PartyRepository repository;

  CancelPartyUseCase(this.repository);

  Future<CancellationResult> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    if (party == null) {
      throw const PartyDomainException('party_not_found', 'Party não encontrada.');
    }
    final result = party.cancel();
    await repository.save(party);
    return result;
  }
}
