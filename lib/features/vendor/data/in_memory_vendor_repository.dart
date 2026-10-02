import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/utils/brazilian_documents.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/domain/vendor_repository.dart';

/// Cadastros de fornecedor em memória, por conta: modo demonstração e testes.
class InMemoryVendorRepository implements VendorRepository, DemoVendorApproval {
  InMemoryVendorRepository({required String? Function() currentUserId})
      : _currentUserId = currentUserId;

  final String? Function() _currentUserId;
  final Map<String, VendorProfile> _profiles = {};
  final Map<String, List<VendorListing>> _listings = {};
  int _sequence = 0;

  String get _userId {
    final userId = _currentUserId();
    if (userId == null) throw const UnauthorizedFailure();
    return userId;
  }

  @override
  Future<VendorProfile?> myProfile() async => _profiles[_userId];

  @override
  Future<List<VendorListing>> myListings() async {
    return List.of(_listings[_userId] ?? const []);
  }

  @override
  Future<VendorProfile> submitHall(HallListingDraft draft) async {
    final userId = _userId;
    final document = normalizeDocument(draft.document);
    final isValid = draft.personType == PersonType.individual
        ? isValidCpf(document)
        : isValidCnpj(document);
    if (!isValid) {
      throw const ValidationFailure('CPF/CNPJ inválido.');
    }

    final existing = _profiles[userId];
    final profile = existing != null && existing.status != VendorStatus.rejected
        ? existing
        : VendorProfile(
            status: VendorStatus.pendingReview,
            legalName: draft.legalName,
            documentMasked: _mask(document),
          );
    _profiles[userId] = profile;
    _listings.putIfAbsent(userId, () => []).insert(
          0,
          VendorListing(
            id: 'demo-listing-${++_sequence}',
            title: draft.title,
            status: VendorListingStatus.pendingReview,
          ),
        );
    return profile;
  }

  @override
  Future<VendorProfile> approveMyProfile() async {
    final userId = _userId;
    final profile = _profiles[userId];
    if (profile == null) throw const NotFoundFailure();

    final approved = VendorProfile(
      status: VendorStatus.approved,
      legalName: profile.legalName,
      documentMasked: profile.documentMasked,
    );
    _profiles[userId] = approved;
    _listings[userId] = [
      for (final listing in _listings[userId] ?? const <VendorListing>[])
        VendorListing(
          id: listing.id,
          title: listing.title,
          status: listing.status == VendorListingStatus.pendingReview
              ? VendorListingStatus.published
              : listing.status,
        ),
    ];
    return approved;
  }

  static String _mask(String document) {
    if (document.length == 11) {
      return '${document.substring(0, 3)}.***.***-${document.substring(9)}';
    }
    return '${document.substring(0, 2)}.***.***/****-${document.substring(12)}';
  }
}
