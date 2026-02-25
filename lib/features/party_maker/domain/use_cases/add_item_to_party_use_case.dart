import '../enums/party_item_category.dart';
import '../repositories/party_repository.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/external_ref.dart';
import '../value_objects/money.dart';
import '../value_objects/party_id.dart';
import '../value_objects/party_item_id.dart';
import '../value_objects/quantity.dart';

class AddItemToPartyUseCase {
  final PartyRepository repository;

  AddItemToPartyUseCase(this.repository);

  Future<void> call({
    required PartyId partyId,
    required PartyItemId partyItemId,
    required ExternalRef externalRef,
    required PartyItemCategory category,
    required String nameSnapshot,
    required Money unitPriceSnapshot,
    required Quantity quantity,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) {
      throw const PartyDomainException('party_not_found', 'Party não encontrada.');
    }

    party.addItem(
      partyItemId: partyItemId,
      externalRef: externalRef,
      category: category,
      nameSnapshot: nameSnapshot,
      unitPriceSnapshot: unitPriceSnapshot,
      quantity: quantity,
    );

    await repository.save(party);
  }
}
