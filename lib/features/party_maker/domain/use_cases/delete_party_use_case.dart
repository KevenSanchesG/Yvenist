import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Apaga a festa de vez.
///
/// Uma festa cujo orçamento os fornecedores estão respondendo precisa ser
/// cancelada antes: assim o pedido não some para eles sem explicação.
class DeletePartyUseCase {
  DeletePartyUseCase(this.repository);

  final PartyRepository repository;

  Future<void> call(PartyId partyId) async {
    final party = await repository.getById(partyId);
    // Já não existia: o resultado desejado é o mesmo.
    if (party == null) return;

    party.ensureCanBeDeleted();
    await repository.deleteById(partyId);
  }
}
