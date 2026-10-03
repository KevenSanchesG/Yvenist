import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Volta uma festa com o orçamento solicitado para o planejamento, para a
/// pessoa poder alterá-la. O que cada fornecedor respondeu continua à vista.
class ReopenPartyUseCase {
  ReopenPartyUseCase(this.repository);

  final PartyRepository repository;

  Future<Party> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.reopenForEditing();
    return repository.save(party);
  }
}
