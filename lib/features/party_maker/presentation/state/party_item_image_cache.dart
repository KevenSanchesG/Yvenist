// lib/features/party_maker/presentation/state/party_item_image_cache.dart

class PartyItemImageCache {
  final Map<String, String> _imageByExternalRefId = {};

  /// Guarda uma URL (ou assetPath) associada a um item do catálogo (externalRefId).
  /// - Não valida se é URL ou asset: a UI decide como renderizar.
  void put({
    required String externalRefId,
    required String imagePath,
  }) {
    if (externalRefId.trim().isEmpty) return;
    if (imagePath.trim().isEmpty) return;

    _imageByExternalRefId[externalRefId] = imagePath;
  }

  /// Retorna a imagem previamente associada ao externalRefId, se existir.
  String? get(String externalRefId) {
    return _imageByExternalRefId[externalRefId];
  }

  /// Remove caso você queira limpar quando o item some do party (opcional).
  void remove(String externalRefId) {
    _imageByExternalRefId.remove(externalRefId);
  }

  /// Útil se você quiser resetar tudo quando começar um novo Party.
  void clear() {
    _imageByExternalRefId.clear();
  }
}
