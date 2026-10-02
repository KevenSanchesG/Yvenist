import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/catalog/data/listing_mapper.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/domain/favorites_repository.dart';

class ApiFavoritesRepository implements FavoritesRepository {
  ApiFavoritesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Listing>> list() async {
    final json = await _api.get('/favorites', authenticated: true) as Json;
    return listingsFromJson(json['items']);
  }

  @override
  Future<void> add(Listing listing) async {
    await _api.put('/favorites/${listing.id}', authenticated: true);
  }

  @override
  Future<void> remove(String listingId) async {
    await _api.delete('/favorites/$listingId', authenticated: true);
  }
}
