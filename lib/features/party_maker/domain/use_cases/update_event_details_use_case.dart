import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Troca os dados do evento: o nome, o tipo, a data e o número de convidados.
class UpdateEventDetailsUseCase {
  UpdateEventDetailsUseCase(this.repository);

  final PartyRepository repository;

  Future<Party> call({
    required PartyId partyId,
    required EventDetails details,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.updateEventDetails(details);
    return repository.save(party);
  }
}
