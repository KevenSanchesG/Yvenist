import '../entities/party.dart';
import '../value_objects/party_id.dart';

abstract class PartyRepository {
  Future<Party?> getById(PartyId id);

  Future<void> save(Party party);

  /// ✅ Necessário para políticas de lifecycle do produto:
  /// Ex.: auto-delete quando party ficar vazia.
  Future<void> deleteById(PartyId id);
}