import 'package:yvenist/features/admin/domain/review_models.dart';

/// Fila de análise de cadastros de fornecedor e de anúncios.
///
/// Só contas de administração conseguem usar: para as demais o servidor
/// responde que não há permissão.
abstract interface class ReviewRepository {
  Future<ReviewQueue> pending();

  /// Aprova o cadastro. Com [publishListings], os anúncios dele que estão em
  /// análise são publicados junto.
  Future<void> approveVendor(String vendorId, {required bool publishListings});

  /// Recusa o cadastro e os anúncios que aguardavam com ele. O fornecedor vê
  /// o [reason].
  Future<void> rejectVendor(String vendorId, {required String reason});

  /// Publica o anúncio. Falha se o fornecedor ainda não foi aprovado.
  Future<void> approveListing(String listingId);

  /// Recusa o anúncio. O fornecedor vê o [reason].
  Future<void> rejectListing(String listingId, {required String reason});
}
