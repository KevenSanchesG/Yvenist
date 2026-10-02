import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

class AddItemToPartyUseCase {
  final PartyRepository repository;

  AddItemToPartyUseCase(this.repository);

  /// Devolve a festa como ficou gravada.
  Future<Party> call({
    required PartyId partyId,
    required PartyItemId partyItemId,
    required ExternalRef externalRef,
    required PartyItemCategory category,
    required String nameSnapshot,
    required Money unitPriceSnapshot,
    required Quantity quantity,
    String? imageUrlSnapshot,
  }) async {
    final party = await repository.getById(partyId);
    if (party == null) throw const PartyNotFound();

    party.addItem(
      partyItemId: partyItemId,
      externalRef: externalRef,
      category: category,
      nameSnapshot: nameSnapshot,
      unitPriceSnapshot: unitPriceSnapshot,
      quantity: quantity,
      imageUrlSnapshot: imageUrlSnapshot,
    );

    return repository.save(party);
  }
}
