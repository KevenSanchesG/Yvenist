import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Guarda as festas na memória do processo: modo demonstração e testes.
class InMemoryPartyRepository implements PartyRepository {
  final Map<String, Party> _store = {};

  // Ordem da última gravação de cada festa. Mais confiável que comparar
  // datas: duas gravações no mesmo instante do relógio continuam ordenadas.
  final Map<String, int> _savedAt = {};
  int _sequence = 0;

  @override
  Future<List<Party>> listByOwner(String ownerId) async {
    final parties = _store.values.where((p) => p.ownerId == ownerId).toList()
      ..sort((a, b) => _savedAt[b.id.value]!.compareTo(_savedAt[a.id.value]!));
    return parties;
  }

  @override
  Future<Party?> getById(PartyId id) async {
    return _store[id.value];
  }

  @override
  Future<Party> save(Party party) async {
    _store[party.id.value] = party;
    _savedAt[party.id.value] = ++_sequence;
    return party;
  }

  @override
  Future<void> deleteById(PartyId id) async {
    _store.remove(id.value);
    _savedAt.remove(id.value);
  }
}
