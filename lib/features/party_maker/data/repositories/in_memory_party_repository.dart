import '../../domain/entities/party.dart';
import '../../domain/repositories/party_repository.dart';
import '../../domain/value_objects/party_id.dart';

class InMemoryPartyRepository implements PartyRepository {
  final Map<String, Party> _store = {};

  @override
  Future<Party?> getById(PartyId id) async => _store[id.value];

  @override
  Future<void> save(Party party) async {
    _store[party.id.value] = party;
  }

  // util do MVP
  List<Party> dumpAll() => _store.values.toList(growable: false);
}
