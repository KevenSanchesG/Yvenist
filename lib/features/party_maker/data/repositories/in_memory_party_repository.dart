import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/repositories/party_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Guarda as festas na memória do processo: modo demonstração e testes.
///
/// Guarda e devolve cópias, como a API: quem recebe uma festa pode alterá-la à
/// vontade, e só o que passa por [save] fica gravado. Sem isso, uma regra que
/// falha no meio de uma operação deixaria a festa guardada pela metade.
class InMemoryPartyRepository implements PartyRepository {
  final Map<String, Party> _store = {};

  // Ordem da última gravação de cada festa. Mais confiável que comparar
  // datas: duas gravações no mesmo instante do relógio continuam ordenadas.
  final Map<String, int> _savedAt = {};
  int _sequence = 0;

  @override
  Future<List<Party>> listByOwner(String ownerId) async {
    return _mostRecentFirst((party) => party.ownerId == ownerId);
  }

  /// As festas de todas as contas, da mais recente para a mais antiga. Fora do
  /// contrato: é por onde o modo demonstração faz o papel dos fornecedores.
  List<Party> all() => _mostRecentFirst((_) => true);

  @override
  Future<Party?> getById(PartyId id) async {
    return _store[id.value]?.clone();
  }

  @override
  Future<Party> save(Party party) async {
    _store[party.id.value] = party.clone();
    _savedAt[party.id.value] = ++_sequence;
    return party.clone();
  }

  @override
  Future<void> deleteById(PartyId id) async {
    _store.remove(id.value);
    _savedAt.remove(id.value);
  }

  List<Party> _mostRecentFirst(bool Function(Party party) keep) {
    final parties = _store.values.where(keep).toList()
      ..sort((a, b) => _savedAt[b.id.value]!.compareTo(_savedAt[a.id.value]!));
    return [for (final party in parties) party.clone()];
  }
}
