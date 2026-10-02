import 'package:flutter/foundation.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// Resultados paginados de uma consulta ao catálogo.
///
/// Serve à aba Explorar e à busca: as duas são a mesma coisa (uma consulta e
/// uma lista que carrega mais ao rolar), mudando só como a consulta é montada.
class ListingSearchController extends ChangeNotifier {
  ListingSearchController(this._catalog, {this.pageSize = 20});

  final CatalogRepository _catalog;
  final int pageSize;

  ListingQuery _query = const ListingQuery();
  final List<Listing> _items = [];
  LoadState<void>? _status;
  String? _nextCursor;
  bool _isLoadingMore = false;
  AppFailure? _loadMoreFailure;
  int _generation = 0;
  bool _disposed = false;

  ListingQuery get query => _query;
  List<Listing> get items => List.unmodifiable(_items);

  /// `null` enquanto nenhuma consulta foi feita.
  LoadState<void>? get status => _status;
  bool get hasSearched => _status != null;
  bool get hasMore => _nextCursor != null;
  bool get isLoadingMore => _isLoadingMore;

  /// Falha ao buscar a página seguinte. Os itens já carregados continuam.
  AppFailure? get loadMoreFailure => _loadMoreFailure;

  /// Executa uma nova consulta, substituindo os resultados atuais.
  Future<void> search(ListingQuery query) async {
    _query = query;
    // Respostas de consultas anteriores que chegarem depois são descartadas.
    final generation = ++_generation;
    _items.clear();
    _nextCursor = null;
    _loadMoreFailure = null;
    _isLoadingMore = false;
    _status = const LoadInProgress();
    _notify();

    try {
      final page = await _catalog.search(query, limit: pageSize);
      if (generation != _generation) return;
      _items.addAll(page.items);
      _nextCursor = page.nextCursor;
      _status = const LoadSuccess(null);
    } catch (error) {
      if (generation != _generation) return;
      _status = LoadFailure(toFailure(error));
    }
    _notify();
  }

  /// Repete a consulta atual (botão "tentar novamente", puxar para atualizar).
  Future<void> refresh() => search(_query);

  /// Busca a página seguinte, se houver e se já não estiver buscando.
  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore) return;

    final generation = _generation;
    _isLoadingMore = true;
    _loadMoreFailure = null;
    _notify();

    try {
      final page = await _catalog.search(_query, cursor: cursor, limit: pageSize);
      if (generation != _generation) return;
      _items.addAll(page.items);
      _nextCursor = page.nextCursor;
    } catch (error) {
      if (generation != _generation) return;
      _loadMoreFailure = toFailure(error);
    }
    _isLoadingMore = false;
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

/// Estado da aba Explorar: os filtros disponíveis e os resultados.
class ExploreController extends ListingSearchController {
  ExploreController(super.catalog, {super.pageSize});

  List<CatalogCategory> _categories = const [];
  List<EventType> _eventTypes = const [];
  bool _started = false;

  List<CatalogCategory> get categories => _categories;
  List<EventType> get eventTypes => _eventTypes;

  /// Carrega os filtros e a primeira página, na primeira vez que a aba abre.
  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    await Future.wait([_loadFilters(), search(query)]);
  }

  /// Aplica um filtro vindo de fora (ex.: toque em uma categoria na Home).
  Future<void> showCategory(String slug) {
    _started = true;
    return Future.wait([
      _loadFilters(),
      search(ListingQuery(categorySlug: slug, sort: query.sort)),
    ]);
  }

  Future<void> showEventType(String slug) {
    _started = true;
    return Future.wait([
      _loadFilters(),
      search(ListingQuery(eventTypeSlug: slug, sort: query.sort)),
    ]);
  }

  /// Liga ou desliga uma categoria (tocar na selecionada limpa o filtro).
  Future<void> toggleCategory(String slug) {
    final selected = query.categorySlug == slug ? null : slug;
    return search(query.copyWith(categorySlug: () => selected));
  }

  Future<void> toggleEventType(String slug) {
    final selected = query.eventTypeSlug == slug ? null : slug;
    return search(query.copyWith(eventTypeSlug: () => selected));
  }

  Future<void> sortBy(ListingSort sort) => search(query.copyWith(sort: sort));

  Future<void> clearFilters() {
    return search(ListingQuery(sort: query.sort));
  }

  Future<void> _loadFilters() async {
    if (_categories.isNotEmpty && _eventTypes.isNotEmpty) return;
    try {
      final results = await Future.wait<Object>([
        _catalog.categories(),
        _catalog.eventTypes(),
      ]);
      _categories = results[0] as List<CatalogCategory>;
      _eventTypes = results[1] as List<EventType>;
      _notify();
    } catch (_) {
      // Sem os filtros a lista continua utilizável; a próxima abertura tenta
      // de novo.
    }
  }
}
