import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

class RemoveItemFromPartyUseCase {
  final PartyRepository repository;

  RemoveItemFromPartyUseCase(this.repository);

  /// Devolve a festa atualizada, ou `null` se ela deixou de existir porque o
  /// último item foi removido.
  Future<Party?> call({
    required PartyId partyId,
    required PartyItemId itemId,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.removeItem(itemId);

    // ✅ Política do produto: Party vazia não deve existir
    if (party.budget.items.isEmpty) {
      await repository.deleteById(partyId);
      return null;
    }

    return repository.save(party);
  }
}
