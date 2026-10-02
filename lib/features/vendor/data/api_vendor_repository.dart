import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
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
                  'person_type': _personTypes[draft.personType],
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
                  'price_from_cents': draft.priceFromCents,
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

  static const Map<PersonType, String> _personTypes = {
    PersonType.individual: 'pf',
    PersonType.company: 'pj',
  };

  static const Map<String, VendorStatus> _statuses = {
    'pending_review': VendorStatus.pendingReview,
    'approved': VendorStatus.approved,
    'rejected': VendorStatus.rejected,
  };

  static const Map<String, VendorListingStatus> _listingStatuses = {
    'draft': VendorListingStatus.draft,
    'pending_review': VendorListingStatus.pendingReview,
    'published': VendorListingStatus.published,
    'rejected': VendorListingStatus.rejected,
    'archived': VendorListingStatus.archived,
  };

  static VendorProfile _profileFromJson(Json json) {
    return VendorProfile(
      // Um status que o app ainda não conhece é tratado como "em análise":
      // não libera nada indevidamente.
      status: _statuses[json['status']] ?? VendorStatus.pendingReview,
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
