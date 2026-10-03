import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/vendor/data/vendor_api_mapping.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/domain/vendor_repository.dart';

class ApiVendorRepository implements VendorRepository {
  ApiVendorRepository(this._api);

  final ApiClient _api;

  @override
  Future<VendorProfile?> myProfile() async {
    try {
      final json = await _api.get('/vendors/me', authenticated: true) as Json;
      return _profileFromJson(json);
    } on NotFoundFailure {
      return null;
    }
  }

  @override
  Future<List<VendorListing>> myListings() async {
    try {
      final json =
          await _api.get('/vendors/me/listings', authenticated: true) as Json;
      return (json['items'] as List)
          .cast<Json>()
          .map(_listingFromJson)
          .toList();
    } on NotFoundFailure {
      // Sem cadastro de fornecedor não há anúncios.
      return const [];
    }
  }

  @override
  Future<VendorProfile> submitHall(HallListingDraft draft) async {
    final json =
        await _api.post(
              '/vendors/onboarding',
              authenticated: true,
              body: {
                'vendor': {
                  'person_type': personTypeToApi[draft.personType],
                  'document': draft.document,
                  'legal_name': draft.legalName,
                },
                'listing': {
                  'category': 'venue',
                  'title': draft.title,
                  'description': draft.description,
                  'neighborhood': draft.neighborhood,
                  'city': draft.city,
                  'state': draft.state,
                  'pricing_model': draft.pricingModel.apiValue,
                  // Sob consulta não tem preço: a API espera zero.
                  'price_from_cents': draft.priceFromCents ?? 0,
                  'minimum_price_cents': draft.minimumPriceCents,
                  'offers': [
                    for (final offer in draft.offers)
                      {
                        'category': offer.categorySlug,
                        'name': offer.name,
                        'pricing_model': offer.pricingModel.apiValue,
                        'price_cents': offer.priceCents ?? 0,
                        'required': offer.isRequired,
                      },
                  ],
                  'capacity': draft.capacity,
                  'area_m2': draft.areaM2,
                  'amenities': draft.amenities.toList(),
                  'event_types': draft.eventTypes.toList(),
                  'cancellation_policy': draft.cancellationPolicy.name,
                },
              },
            )
            as Json;
    return _profileFromJson(json['vendor'] as Json);
  }

  static const Map<String, VendorListingStatus> _listingStatuses = {
    'draft': VendorListingStatus.draft,
    'pending_review': VendorListingStatus.pendingReview,
    'published': VendorListingStatus.published,
    'rejected': VendorListingStatus.rejected,
    'archived': VendorListingStatus.archived,
  };

  static VendorProfile _profileFromJson(Json json) {
    return VendorProfile(
      status: vendorStatusFromApi(json['status']),
      legalName: json['legal_name'] as String,
      documentMasked: json['document_masked'] as String,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  static VendorListing _listingFromJson(Json json) {
    return VendorListing(
      id: json['id'] as String,
      title: json['title'] as String,
      status:
          _listingStatuses[json['status']] ?? VendorListingStatus.pendingReview,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
