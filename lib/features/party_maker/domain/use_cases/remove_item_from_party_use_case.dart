import '../repositories/party_repository.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/party_id.dart';
import '../value_objects/party_item_id.dart';

class RemoveItemFromPartyUseCase {
  final PartyRepository repository;

  RemoveItemFromPartyUseCase(this.repository);

  Future<void> call({
    required PartyId partyId,
    required PartyItemId itemId,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) {
      throw const PartyDomainException('party_not_found', 'Party não encontrada.');
    }

    party.removeItem(itemId);

    // ✅ Política do produto: Party vazia não deve existir
    if (party.budget.items.isEmpty) {
      await repository.deleteById(partyId);
      return;
    }

    await repository.save(party);
  }
}