import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// A pessoa aceita o orçamento que recebeu dos fornecedores.
class ConfirmQuoteUseCase {
  ConfirmQuoteUseCase(this.repository);

  final PartyRepository repository;

  Future<Party> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.confirmQuote();
    return repository.save(party);
  }
}
