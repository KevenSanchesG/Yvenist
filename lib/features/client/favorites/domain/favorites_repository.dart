import 'package:yvenist/features/catalog/domain/entities/listing.dart';

/// Favoritos da conta autenticada.
abstract interface class FavoritesRepository {
  /// Do mais recente para o mais antigo.
  Future<List<Listing>> list();

  /// Favoritar duas vezes o mesmo anúncio não tem efeito.
  Future<void> add(Listing listing);

  /// Remover o que não está favoritado não é erro.
  Future<void> remove(String listingId);
}
