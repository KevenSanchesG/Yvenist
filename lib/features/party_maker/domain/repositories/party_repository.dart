import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';

/// Contrato de persistência das festas. O domínio e a apresentação só
/// conhecem esta interface; a implementação (memória, API) fica em `data/`.
abstract interface class PartyRepository {
  /// Festas do dono, da mais recente para a mais antiga.
  Future<List<Party>> listByOwner(String ownerId);

  Future<Party?> getById(PartyId id);

  /// Grava a festa e devolve como ela ficou armazenada.
  ///
  /// O armazenamento é a autoridade: a API, por exemplo, copia nome e preço
  /// dos itens direto do catálogo, então o que volta pode diferir do enviado.
  Future<Party> save(Party party);

  /// ✅ Necessário para políticas de lifecycle do produto:
  /// Ex.: auto-delete quando party ficar vazia.
  Future<void> deleteById(PartyId id);
}
