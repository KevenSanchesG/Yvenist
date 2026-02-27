import '../repositories/party_repository.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/party_id.dart';
import '../value_objects/party_title.dart';

class RenamePartyTitleUseCase {
  final PartyRepository repository;

  RenamePartyTitleUseCase(this.repository);

  Future<void> call({
    required PartyId partyId,
    required PartyTitle newTitle,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) {
      throw const PartyDomainException('party_not_found', 'Party não encontrada.');
    }

    party.updateTitle(newTitle);
    await repository.save(party);
  }
}