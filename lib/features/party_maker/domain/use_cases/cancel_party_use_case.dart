import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Cancela a festa. Ela continua na lista, como cancelada, e os fornecedores
/// que tinham recebido o pedido ficam sabendo.
class CancelPartyUseCase {
  CancelPartyUseCase(this.repository);

  final PartyRepository repository;

  Future<Party> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.cancel();
    return repository.save(party);
  }
}
