import 'package:yvenist/features/party_maker/domain/value_objects/party_item_draft.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// Um item do catálogo do jeito que a pessoa o configurou, pronto para entrar
/// em uma festa (ou para substituir a configuração de um que já está nela).
///
/// A configuração chega como a pessoa preencheu ([configuration], pela chave de
/// cada campo): quem confere e limpa são as regras da categoria, na hora de
/// entrar.
class ConfiguredItem {
  const ConfiguredItem({
    required this.draft,
    this.quantity = 1,
    this.configuration = const {},
    this.ownServices = const [],
    this.recommendedBy,
  });

  final PartyItemDraft draft;
  final int quantity;
  final Map<String, Object?> configuration;

  /// Os serviços do próprio anunciante que a pessoa quis junto.
  final List<ConfiguredItem> ownServices;

  /// O item da festa que recomendou este, quando ele veio de uma indicação.
  final PartyItemId? recommendedBy;
}
