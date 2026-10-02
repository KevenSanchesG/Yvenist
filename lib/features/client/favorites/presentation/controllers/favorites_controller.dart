import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/domain/favorites_repository.dart';

/// Favoritos da conta para as telas: quais são e como alternar.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repository);

  final FavoritesRepository _repository;

  final List<Listing> _items = [];
  final Set<String> _pending = {};
  Future<void>? _loading;
  String? _userId;
  bool _hasLoaded = false;
  String? _loadError;
  String? _error;
  bool _disposed = false;

  List<Listing> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get hasLoaded => _hasLoaded;
  String? get loadError => _loadError;

  /// Mensagem da última alternância que falhou.
  String? get error => _error;

  bool isFavorite(String listingId) {
    return _items.any((listing) => listing.id == listingId);
  }

  /// Troca a conta (login, logout): esvazia e recarrega os favoritos dela.
  Future<void> setUser(String? userId) async {
    if (userId == _userId && _hasLoaded) return;
    _userId = userId;
    _items.clear();
    _error = null;
    _loadError = null;
    _hasLoaded = false;
    await load();
  }

  Future<void> load() {
    return _loading = _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      _items.clear();
      _hasLoaded = true;
      _notify();
      return;
    }

    try {
      final loaded = await _repository.list();
      if (userId != _userId) return;
      _items
        ..clear()
        ..addAll(loaded);
      _loadError = null;
    } catch (error) {
      if (userId != _userId) return;
      _loadError = describeFailure(error);
    } finally {
      if (userId == _userId) {
        _hasLoaded = true;
        _notify();
      }
    }
  }

  /// Favorita ou desfavorita. A tela muda na hora e, se o servidor recusar,
  /// volta ao que era; devolve se a alternância foi confirmada.
  Future<bool> toggle(Listing listing) async {
    // Toques repetidos no mesmo coração enquanto o primeiro ainda não foi
    // confirmado são ignorados, para as respostas não se atropelarem.
    if (!_pending.add(listing.id)) return false;
    // Espera uma carga em andamento (ex.: logo após o login) para que o
    // resultado dela não sobrescreva esta alternância.
    await _loading;

    final wasFavorite = isFavorite(listing.id);
    _error = null;
    _setFavorite(listing, !wasFavorite);

    try {
      if (wasFavorite) {
        await _repository.remove(listing.id);
      } else {
        await _repository.add(listing);
      }
      return true;
    } catch (error) {
      _error = describeFailure(error);
      _setFavorite(listing, wasFavorite);
      return false;
    } finally {
      _pending.remove(listing.id);
    }
  }

  void _setFavorite(Listing listing, bool favorite) {
    _items.removeWhere((item) => item.id == listing.id);
    if (favorite) _items.insert(0, listing);
    _notify();
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
