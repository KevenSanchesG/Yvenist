import 'package:yvenist/features/vendor/domain/vendor_models.dart';

/// Cadastro de fornecedor e anúncios próprios da conta autenticada.
abstract interface class VendorRepository {
  /// `null` quando a conta ainda não tem cadastro de fornecedor.
  Future<VendorProfile?> myProfile();

  Future<List<VendorListing>> myListings();

  /// Envia o cadastro (na primeira vez) e o anúncio do salão para análise.
  Future<VendorProfile> submitHall(HallListingDraft draft);
}

/// Capacidade extra do modo demonstração: aprovar o próprio cadastro, já que
/// não há um administrador para fazer isso.
abstract interface class DemoVendorApproval {
  Future<VendorProfile> approveMyProfile();
}
