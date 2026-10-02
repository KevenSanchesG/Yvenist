import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/domain/vendor_repository.dart';

/// Situação da conta como fornecedora, para as telas.
class VendorController extends ChangeNotifier {
  VendorController(this._repository);

  final VendorRepository _repository;

  String? _userId;
  VendorProfile? _profile;
  List<VendorListing> _listings = const [];
  bool _hasLoaded = false;
  bool _isBusy = false;
  AppFailure? _failure;
  bool _disposed = false;

  VendorProfile? get profile => _profile;
  VendorStatus get status => _profile?.status ?? VendorStatus.none;
  bool get isApproved => status == VendorStatus.approved;
  List<VendorListing> get listings => _listings;
  bool get hasLoaded => _hasLoaded;
  bool get isBusy => _isBusy;

  /// Falha da última operação, para a tela exibir.
  AppFailure? get failure => _failure;

  /// Só o modo demonstração permite aprovar o próprio cadastro.
  bool get canSimulateApproval => _repository is DemoVendorApproval;

  int countListings(VendorListingStatus status) {
    return _listings.where((listing) => listing.status == status).length;
  }

  Future<void> setUser(String? userId) async {
    if (userId == _userId && _hasLoaded) return;
    _userId = userId;
    _profile = null;
    _listings = const [];
    _failure = null;
    _hasLoaded = false;
    await load();
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) {
      _hasLoaded = true;
      _notify();
      return;
    }

    try {
      final profile = await _repository.myProfile();
      final listings = profile == null
          ? const <VendorListing>[]
          : await _repository.myListings();
      if (userId != _userId) return;
      _profile = profile;
      _listings = listings;
    } catch (_) {
      // Sem conseguir consultar, a conta é tratada como não fornecedora: nada
      // do modo fornecedor é liberado por engano. A próxima carga tenta de novo.
      if (userId != _userId) return;
    }
    _hasLoaded = true;
    _notify();
  }

  /// Envia o salão para análise. Devolve se deu certo.
  Future<bool> submitHall(HallListingDraft draft) {
    return _run(() async {
      _profile = await _repository.submitHall(draft);
      _listings = await _repository.myListings();
    });
  }

  Future<bool> simulateApproval() {
    // Declarado como Object para o teste de tipo promover a variável (as duas
    // interfaces não têm relação de herança entre si).
    final Object repository = _repository;
    if (repository is! DemoVendorApproval) return Future.value(false);
    return _run(() async {
      _profile = await repository.approveMyProfile();
      _listings = await _repository.myListings();
    });
  }

  void clearError() {
    if (_failure == null) return;
    _failure = null;
    _notify();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _failure = null;
    _isBusy = true;
    _notify();
    try {
      await action();
      return true;
    } catch (error) {
      _failure = error is AppFailure ? error : const UnexpectedFailure();
      return false;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
