import 'package:flutter/foundation.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

/// Uma faixa da Home: título e os anúncios de uma categoria.
class HomeSection {
  const HomeSection({
    required this.title,
    required this.subtitle,
    required this.categorySlug,
    required this.listings,
  });

  final String title;
  final String subtitle;
  final String categorySlug;
  final List<Listing> listings;
}

/// Tudo que a Home mostra depois de carregar.
class HomeFeed {
  const HomeFeed({
    required this.categories,
    required this.eventTypes,
    required this.sections,
  });

  final List<CatalogCategory> categories;
  final List<EventType> eventTypes;

  /// Só as faixas que têm ao menos um anúncio.
  final List<HomeSection> sections;
}

class HomeController extends ChangeNotifier {
  HomeController(this._catalog);

  /// Quantos anúncios cada faixa mostra.
  static const int listingsPerSection = 8;

  static const List<({String title, String subtitle, String category})>
      _sections = [
    (
      title: 'Salões muito procurados',
      subtitle: 'Descubra os melhores espaços para sua festa',
      category: 'venue',
    ),
    (
      title: 'Atrações que estão em alta nas festas',
      subtitle: 'Dê vida a sua festa com as melhores opções',
      category: 'attraction',
    ),
  ];

  final CatalogRepository _catalog;

  LoadState<HomeFeed> _state = const LoadInProgress();
  bool _disposed = false;

  LoadState<HomeFeed> get state => _state;

  Future<void> load() async {
    // Ao atualizar puxando a tela, o conteúdo atual continua visível.
    if (_state is! LoadSuccess<HomeFeed>) {
      _state = const LoadInProgress();
      _notify();
    }

    try {
      // As buscas são independentes: rodam em paralelo, não uma após a outra.
      final results = await Future.wait<Object>([
        _catalog.categories(),
        _catalog.eventTypes(),
        for (final section in _sections)
          _catalog.search(
            ListingQuery(categorySlug: section.category),
            limit: listingsPerSection,
          ),
      ]);
      final pages = results.skip(2).cast<ListingPage>().toList();

      _state = LoadSuccess(
        HomeFeed(
          categories: results[0] as List<CatalogCategory>,
          eventTypes: results[1] as List<EventType>,
          sections: [
            for (final (index, section) in _sections.indexed)
              if (pages[index].items.isNotEmpty)
                HomeSection(
                  title: section.title,
                  subtitle: section.subtitle,
                  categorySlug: section.category,
                  listings: pages[index].items,
                ),
          ],
        ),
      );
    } catch (error) {
      // Se já havia conteúdo (atualização que falhou), mantém o que estava.
      if (_state is! LoadSuccess<HomeFeed>) _state = LoadFailure(toFailure(error));
    }
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
