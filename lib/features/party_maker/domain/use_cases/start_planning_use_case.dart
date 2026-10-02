import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

class StartPlanningUseCase {
  final PartyRepository repository;

  StartPlanningUseCase(this.repository);

  Future<Party> call(PartyId id) async {
    final party = await repository.getById(id);
    if (party == null) throw const PartyNotFound();

    party.startPlanning();
    return repository.save(party);
  }
}
