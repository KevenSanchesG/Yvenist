import '../repositories/party_repository.dart';
import '../value_objects/party_id.dart';
import '../rules/party_domain_exceptions.dart';

class StartPlanningUseCase {
  final PartyRepository repository;

  StartPlanningUseCase(this.repository);

  Future<void> call(PartyId id) async {
    final party = await repository.getById(id);
    if (party == null) {
      throw const PartyDomainException('party_not_found', 'Party não encontrada.');
    }
    party.startPlanning();
    await repository.save(party);
  }
}
