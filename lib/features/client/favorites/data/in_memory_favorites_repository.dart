import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/domain/favorites_repository.dart';

/// Favoritos em memória, separados por conta: modo demonstração e testes.
class InMemoryFavoritesRepository implements FavoritesRepository {
  InMemoryFavoritesRepository({required String? Function() currentUserId})
    : _currentUserId = currentUserId;

  final String? Function() _currentUserId;
  final Map<String, List<Listing>> _byUser = {};

  List<Listing> get _mine {
    final userId = _currentUserId();
    if (userId == null) throw const UnauthorizedFailure();
    return _byUser.putIfAbsent(userId, () => []);
  }

  @override
  Future<List<Listing>> list() async => List.of(_mine);

  @override
  Future<void> add(Listing listing) async {
    final favorites = _mine;
    if (!favorites.contains(listing)) favorites.insert(0, listing);
  }

  @override
  Future<void> remove(String listingId) async {
    _mine.removeWhere((listing) => listing.id == listingId);
  }
}
