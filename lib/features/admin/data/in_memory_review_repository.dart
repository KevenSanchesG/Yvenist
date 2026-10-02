import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

/// Fila de análise em memória: modo demonstração e testes.
///
/// Segue as mesmas regras do servidor. No modo demonstração a fila começa
/// vazia e a conta de demonstração não é de administração, então a tela só é
/// alcançada nos testes.
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({
    List<VendorReview> vendors = const [],
    List<ListingReview> listings = const [],
  }) : _vendors = List.of(vendors),
       _listings = List.of(listings);

  final List<VendorReview> _vendors;
  final List<ListingReview> _listings;

  @override
  Future<ReviewQueue> pending() async {
    return ReviewQueue(
      vendors: List.unmodifiable(_vendors),
      listings: List.unmodifiable(_listings),
    );
  }

  @override
  Future<void> approveVendor(
    String vendorId, {
    required bool publishListings,
  }) async {
    _takeVendor(vendorId);
    if (publishListings) {
      _listings.removeWhere((listing) => listing.vendorId == vendorId);
      return;
    }
    // Os anúncios continuam na fila, agora de um fornecedor aprovado.
    for (var index = 0; index < _listings.length; index++) {
      final listing = _listings[index];
      if (listing.vendorId == vendorId) {
        _listings[index] = listing.withVendorStatus(VendorStatus.approved);
      }
    }
  }

  @override
  Future<void> rejectVendor(String vendorId, {required String reason}) async {
    _checkReason(reason);
    _takeVendor(vendorId);
    _listings.removeWhere((listing) => listing.vendorId == vendorId);
  }

  @override
  Future<void> approveListing(String listingId) async {
    final listing = _findListing(listingId);
    if (!listing.canBePublished) {
      throw const ConflictFailure(
        'O anúncio só pode ser publicado depois que o fornecedor for aprovado.',
        'vendor_not_approved',
      );
    }
    _listings.remove(listing);
  }

  @override
  Future<void> rejectListing(String listingId, {required String reason}) async {
    _checkReason(reason);
    _listings.remove(_findListing(listingId));
  }

  /// Tira o cadastro da fila. Quem não está nela já foi analisado.
  void _takeVendor(String vendorId) {
    final index = _vendors.indexWhere((vendor) => vendor.id == vendorId);
    if (index < 0) throw _alreadyReviewed;
    _vendors.removeAt(index);
  }

  ListingReview _findListing(String listingId) {
    return _listings.firstWhere(
      (listing) => listing.id == listingId,
      orElse: () => throw _alreadyReviewed,
    );
  }

  static void _checkReason(String reason) {
    if (reason.trim().length < 5) {
      throw const ValidationFailure(
        'Explique o motivo da recusa.',
        fieldErrors: {'reason': 'Explique o motivo da recusa.'},
      );
    }
  }

  static const ConflictFailure _alreadyReviewed = ConflictFailure(
    'Este item já foi analisado.',
    'already_reviewed',
  );
}
