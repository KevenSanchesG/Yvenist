import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// Tira um item da festa.
///
/// A festa continua existindo, mesmo sem itens: os dados do evento ficam, e a
/// pessoa segue montando. Apagar a festa é outra ação (`DeletePartyUseCase`).
class RemoveItemFromPartyUseCase {
  RemoveItemFromPartyUseCase(this.repository);

  final PartyRepository repository;

  /// Devolve a festa como ficou gravada e o que a remoção fez com os outros
  /// itens: o que saiu junto e o que ficou solto.
  Future<({Party party, ItemRemoval removal})> call({
    required PartyId partyId,
    required PartyItemId itemId,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    final removal = party.removeItem(itemId);
    return (party: await repository.save(party), removal: removal);
  }
}
