import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/catalog/data/listing_mapper.dart';
import 'package:yvenist/features/vendor/data/vendor_api_mapping.dart';

class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._api);

  static const Map<String, String?> _pending = {'status': 'pending_review'};

  final ApiClient _api;

  @override
  Future<ReviewQueue> pending() async {
    // As duas filas são independentes: buscadas em paralelo.
    final results = await Future.wait([
      _api.get('/admin/vendors', query: _pending, authenticated: true),
      _api.get('/admin/listings', query: _pending, authenticated: true),
    ]);
    return ReviewQueue(
      vendors: _items(results[0]).map(_vendorFromJson).toList(),
      listings: _items(results[1]).map(_listingFromJson).toList(),
    );
  }

  @override
  Future<void> approveVendor(
    String vendorId, {
    required bool publishListings,
  }) async {
    await _api.post(
      '/admin/vendors/$vendorId/approve',
      authenticated: true,
      body: {'publish_pending_listings': publishListings},
    );
  }

  @override
  Future<void> rejectVendor(String vendorId, {required String reason}) async {
    await _api.post(
      '/admin/vendors/$vendorId/reject',
      authenticated: true,
      body: {'reason': reason},
    );
  }

  @override
  Future<void> approveListing(String listingId) async {
    await _api.post('/admin/listings/$listingId/approve', authenticated: true);
  }

  @override
  Future<void> rejectListing(String listingId, {required String reason}) async {
    await _api.post(
      '/admin/listings/$listingId/reject',
      authenticated: true,
      body: {'reason': reason},
    );
  }

  static Iterable<Json> _items(Object? response) {
    return ((response! as Json)['items'] as List).cast<Json>();
  }

  static VendorReview _vendorFromJson(Json json) {
    return VendorReview(
      id: json['id'] as String,
      legalName: json['legal_name'] as String,
      personType: personTypeFromApi(json['person_type']),
      document: json['document'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static ListingReview _listingFromJson(Json json) {
    final pricing = pricingFromJson(
      json['pricing_model'],
      json['price_from_cents'],
    );
    return ListingReview(
      id: json['id'] as String,
      title: json['title'] as String,
      categorySlug: json['category'] as String,
      description: json['description'] as String,
      neighborhood: json['neighborhood'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pricingModel: pricing.model,
      priceFromCents: pricing.cents,
      minimumPriceCents: json['minimum_price_cents'] as int?,
      offers: [
        for (final offer in (json['offers'] as List? ?? const []).cast<Json>())
          listingOfferFromJson(offer),
      ],
      capacity: json['capacity'] as int?,
      areaM2: json['area_m2'] as int?,
      amenities: (json['amenities'] as List).cast<String>(),
      eventTypes: (json['event_types'] as List).cast<String>(),
      cancellationPolicy: cancellationPolicyFromApi(
        json['cancellation_policy'],
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      vendorId: json['vendor_id'] as String,
      vendorName: json['vendor_legal_name'] as String,
      vendorStatus: vendorStatusFromApi(json['vendor_status']),
    );
  }
}
