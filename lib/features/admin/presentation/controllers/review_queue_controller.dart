import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/admin/domain/review_models.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// A fila de análise e as decisões sobre ela.
class ReviewQueueController extends ChangeNotifier {
  ReviewQueueController({
    required ReviewRepository reviews,
    required CatalogRepository catalog,
  }) : _reviews = reviews,
       _catalog = catalog;

  final ReviewRepository _reviews;
  final CatalogRepository _catalog;

  LoadState<ReviewQueue> _state = const LoadInProgress();
  Map<String, String> _categoryNames = const {};
  Map<String, String> _eventTypeNames = const {};
  final Set<String> _deciding = {};
  bool _disposed = false;

  LoadState<ReviewQueue> get state => _state;

  /// Há uma decisão em andamento sobre o cadastro ou anúncio [id].
  bool isDeciding(String id) => _deciding.contains(id);

  /// Nome de uma categoria. Sem conseguir consultar o catálogo, a própria
  /// chave: a fila continua utilizável.
  String categoryName(String slug) => _categoryNames[slug] ?? slug;

  String eventTypeName(String slug) => _eventTypeNames[slug] ?? slug;

  Future<void> load() async {
    // Ao atualizar, o conteúdo atual continua visível.
    if (_state is! LoadSuccess<ReviewQueue>) {
      _state = const LoadInProgress();
      _notify();
    }

    try {
      final labels = _loadLabels();
      final queue = await _reviews.pending();
      await labels;
      _state = LoadSuccess(queue);
    } catch (error) {
      // Se já havia conteúdo (atualização que falhou), mantém o que estava.
      if (_state is! LoadSuccess<ReviewQueue>) {
        _state = LoadFailure(toFailure(error));
      }
    }
    _notify();
  }

  // As decisões devolvem a falha, ou `null` quando deram certo.

  Future<AppFailure?> approveVendor(
    VendorReview vendor, {
    required bool publishListings,
  }) {
    return _decide(
      vendor.id,
      () => _reviews.approveVendor(vendor.id, publishListings: publishListings),
    );
  }

  Future<AppFailure?> rejectVendor(VendorReview vendor, String reason) {
    return _decide(
      vendor.id,
      () => _reviews.rejectVendor(vendor.id, reason: reason),
    );
  }

  Future<AppFailure?> approveListing(ListingReview listing) {
    return _decide(listing.id, () => _reviews.approveListing(listing.id));
  }

  Future<AppFailure?> rejectListing(ListingReview listing, String reason) {
    return _decide(
      listing.id,
      () => _reviews.rejectListing(listing.id, reason: reason),
    );
  }

  Future<AppFailure?> _decide(String id, Future<void> Function() action) async {
    if (!_deciding.add(id)) return null; // toque duplo: a primeira já decide
    _notify();

    AppFailure? failure;
    try {
      await action();
    } catch (error) {
      failure = toFailure(error);
    }
    // Recarrega mesmo quando falha: se outra pessoa já tinha decidido, o item
    // some da tela em vez de continuar oferecendo uma decisão impossível.
    await load();
    _deciding.remove(id);
    _notify();
    return failure;
  }

  Future<void> _loadLabels() async {
    if (_categoryNames.isNotEmpty && _eventTypeNames.isNotEmpty) return;
    try {
      final results = await Future.wait<Object>([
        _catalog.categories(),
        _catalog.eventTypes(),
      ]);
      _categoryNames = {
        for (final category in results[0] as List<CatalogCategory>)
          category.slug: category.name,
      };
      _eventTypeNames = {
        for (final type in results[1] as List<EventType>) type.slug: type.name,
      };
    } catch (_) {
      // Os nomes são um acabamento; sem eles a tela mostra as chaves.
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
