import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';

class RenamePartyTitleUseCase {
  final PartyRepository repository;

  RenamePartyTitleUseCase(this.repository);

  Future<Party> call({
    required PartyId partyId,
    required PartyTitle newTitle,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.updateTitle(newTitle);
    return repository.save(party);
  }
}
