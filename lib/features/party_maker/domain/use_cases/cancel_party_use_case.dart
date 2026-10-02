import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/cancellation_result.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

class CancelPartyUseCase {
  final PartyRepository repository;

  CancelPartyUseCase(this.repository);

  Future<CancellationResult> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    final result = party.cancel();
    await repository.save(party);
    return result;
  }
}
