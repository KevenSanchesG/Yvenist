import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/state/load_state.dart';
import 'package:yvenist/features/catalog/data/demo_catalog.dart';
import 'package:yvenist/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/client/home/presentation/controllers/home_controller.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';

import '../../support/catalog_fixtures.dart';

void main() {
  late ControllableCatalog catalog;

  setUp(() => catalog = ControllableCatalog());

  group('HomeController', () {
    late HomeController controller;

    setUp(() => controller = HomeController(catalog));
    tearDown(() => controller.dispose());

    test('começa carregando', () {
      expect(controller.state, isA<LoadInProgress<HomeFeed>>());
    });

    test(
      'carrega categorias, tipos de evento e as faixas com anúncios',
      () async {
        await controller.load();

        final feed = controller.state.valueOrNull!;
        expect(feed.categories, isNotEmpty);
        expect(feed.eventTypes, isNotEmpty);
        expect(feed.sections.map((s) => s.categorySlug), [
          'venue',
          'attraction',
        ]);
        expect(feed.sections.first.title, 'Salões muito procurados');
        expect(
          feed.sections.first.listings,
          hasLength(HomeController.listingsPerSection),
        );
        expect(feed.sections.first.listings.first.title, 'Salão Glamour 8');
      },
    );

    test('faixa sem anúncios não aparece', () async {
      final onlyVenues = HomeController(
        InMemoryCatalogRepository(
          listings: buildDemoListings()
              .where((entry) => entry.listing.categorySlug == 'venue')
              .toList(),
        ),
      );
      addTearDown(onlyVenues.dispose);

      await onlyVenues.load();

      final sections = onlyVenues.state.valueOrNull!.sections;
      expect(sections.map((s) => s.categorySlug), ['venue']);
    });

    test('catálogo vazio carrega com sucesso e nenhuma faixa', () async {
      final empty = HomeController(
        InMemoryCatalogRepository(listings: const []),
      );
      addTearDown(empty.dispose);

      await empty.load();

      expect(empty.state, isA<LoadSuccess<HomeFeed>>());
      expect(empty.state.valueOrNull!.sections, isEmpty);
    });

    test('falha vira estado de erro com mensagem para o usuário', () async {
      catalog.failure = const NetworkFailure();

      await controller.load();

      final state = controller.state;
      expect(state, isA<LoadFailure<HomeFeed>>());
      expect((state as LoadFailure<HomeFeed>).failure, isA<NetworkFailure>());
    });

    test('tentar de novo depois de uma falha carrega o conteúdo', () async {
      catalog.failure = const NetworkFailure();
      await controller.load();

      catalog.failure = null;
      await controller.load();

      expect(controller.state, isA<LoadSuccess<HomeFeed>>());
    });

    test(
      'atualização que falha mantém o conteúdo que já estava na tela',
      () async {
        await controller.load();
        catalog.failure = const NetworkFailure();

        await controller.load();

        expect(controller.state, isA<LoadSuccess<HomeFeed>>());
      },
    );

    test('erro inesperado nunca expõe detalhe técnico', () async {
      catalog.failure = StateError('falha interna');

      await controller.load();

      final failure = (controller.state as LoadFailure<HomeFeed>).failure;
      expect(failure, isA<UnexpectedFailure>());
    });
  });

  group('ListingSearchController', () {
    late ListingSearchController controller;

    setUp(() => controller = ListingSearchController(catalog, pageSize: 5));
    tearDown(() => controller.dispose());

    test('antes de qualquer busca não há status', () {
      expect(controller.hasSearched, isFalse);
      expect(controller.status, isNull);
      expect(controller.items, isEmpty);
    });

    test('busca e guarda a primeira página', () async {
      await controller.search(const ListingQuery(categorySlug: 'venue'));

      expect(controller.status, isA<LoadSuccess<void>>());
      expect(controller.items, hasLength(5));
      expect(controller.hasMore, isTrue);
      expect(controller.query.categorySlug, 'venue');
    });

    test('fica carregando enquanto a resposta não chega', () async {
      catalog.gate = Completer<void>();

      final pending = controller.search(const ListingQuery());
      expect(controller.status, isA<LoadInProgress<void>>());

      catalog.gate!.complete();
      await pending;
      expect(controller.status, isA<LoadSuccess<void>>());
    });

    test('busca sem resultado termina com sucesso e lista vazia', () async {
      await controller.search(const ListingQuery(text: 'inexistente'));

      expect(controller.status, isA<LoadSuccess<void>>());
      expect(controller.items, isEmpty);
      expect(controller.hasMore, isFalse);
    });

    test(
      'falha na busca vira estado de erro, e refresh tenta de novo',
      () async {
        catalog.searchFailure = const NetworkFailure();
        await controller.search(const ListingQuery(categorySlug: 'venue'));
        expect(controller.status, isA<LoadFailure<void>>());

        catalog.searchFailure = null;
        await controller.refresh();

        expect(controller.status, isA<LoadSuccess<void>>());
        expect(controller.items, isNotEmpty);
      },
    );

    test('loadMore acrescenta as páginas seguintes até acabar', () async {
      await controller.search(const ListingQuery(categorySlug: 'venue'));

      await controller.loadMore();
      expect(controller.items, hasLength(8));
      expect(controller.hasMore, isFalse);

      await controller.loadMore(); // não há mais o que buscar
      expect(controller.items, hasLength(8));
      expect(controller.items.map((l) => l.id).toSet(), hasLength(8));
    });

    test('loadMore envia o cursor da página anterior', () async {
      await controller.search(const ListingQuery());
      await controller.loadMore();

      expect(catalog.cursors, [null, '5']);
    });

    test('chamadas simultâneas de loadMore buscam uma página só', () async {
      await controller.search(const ListingQuery());
      catalog.gate = Completer<void>();

      final first = controller.loadMore();
      final second = controller.loadMore();
      expect(controller.isLoadingMore, isTrue);
      catalog.gate!.complete();
      await Future.wait([first, second]);

      expect(controller.items, hasLength(10));
      expect(catalog.cursors, [null, '5']);
    });

    test(
      'falha ao buscar mais mantém os itens e permite tentar de novo',
      () async {
        await controller.search(const ListingQuery());
        catalog.searchFailure = const NetworkFailure();

        await controller.loadMore();

        expect(controller.items, hasLength(5));
        expect(controller.loadMoreFailure, isA<NetworkFailure>());
        expect(controller.status, isA<LoadSuccess<void>>());
        expect(controller.hasMore, isTrue);

        catalog.searchFailure = null;
        await controller.loadMore();
        expect(controller.items, hasLength(10));
        expect(controller.loadMoreFailure, isNull);
      },
    );

    test(
      'resposta de uma busca antiga não sobrescreve a mais recente',
      () async {
        // A pessoa digita "salão" e, antes de a resposta chegar, troca para
        // "atração". A resposta de "salão" chega por último e é ignorada.
        final slow = Completer<void>();
        catalog.gate = slow;
        final stale = controller.search(const ListingQuery(text: 'salão'));

        catalog.gate = null;
        await controller.search(const ListingQuery(text: 'atração'));
        slow.complete();
        await stale;

        expect(controller.query.text, 'atração');
        expect(
          controller.items.every((l) => l.title.startsWith('Atração')),
          isTrue,
        );
      },
    );

    test('uma nova busca descarta os resultados anteriores', () async {
      await controller.search(const ListingQuery(categorySlug: 'venue'));
      await controller.loadMore();

      await controller.search(const ListingQuery(categorySlug: 'buffet'));

      expect(controller.items, hasLength(5));
      expect(controller.items.every((l) => l.categorySlug == 'buffet'), isTrue);
    });
  });

  group('ExploreController', () {
    late ExploreController controller;

    setUp(() => controller = ExploreController(catalog, pageSize: 5));
    tearDown(() => controller.dispose());

    test('na primeira abertura carrega filtros e a primeira página', () async {
      await controller.ensureStarted();

      expect(controller.categories, isNotEmpty);
      expect(controller.eventTypes, isNotEmpty);
      expect(controller.items, hasLength(5));
    });

    test('ensureStarted só busca uma vez', () async {
      await controller.ensureStarted();
      await controller.ensureStarted();

      expect(catalog.queries, hasLength(1));
    });

    test(
      'showCategory aplica o filtro vindo de fora e dispensa a carga inicial',
      () async {
        await controller.showCategory('attraction');
        await controller.ensureStarted();

        expect(controller.query.categorySlug, 'attraction');
        expect(controller.categories, isNotEmpty);
        expect(catalog.queries, hasLength(1));
        expect(
          controller.items.every((l) => l.categorySlug == 'attraction'),
          isTrue,
        );
      },
    );

    test('showEventType filtra pelo tipo de evento', () async {
      await controller.showEventType('wedding');

      expect(controller.query.eventTypeSlug, 'wedding');
      expect(controller.query.categorySlug, isNull);
      expect(controller.items, isNotEmpty);
    });

    test(
      'tocar em uma categoria liga o filtro; tocar de novo desliga',
      () async {
        await controller.ensureStarted();

        await controller.toggleCategory('venue');
        expect(controller.query.categorySlug, 'venue');

        await controller.toggleCategory('venue');
        expect(controller.query.categorySlug, isNull);
      },
    );

    test('categoria e tipo de evento combinam', () async {
      await controller.toggleCategory('decoration');
      await controller.toggleEventType('wedding');

      expect(controller.query.categorySlug, 'decoration');
      expect(controller.query.eventTypeSlug, 'wedding');
      expect(controller.items, isNotEmpty);
    });

    test('trocar a ordenação mantém os filtros', () async {
      await controller.toggleCategory('venue');

      await controller.sortBy(ListingSort.priceAsc);

      expect(controller.query.categorySlug, 'venue');
      expect(controller.query.sort, ListingSort.priceAsc);
      expect(controller.items.first.title, 'Salão Glamour 1');
    });

    test('limpar filtros mantém a ordenação', () async {
      await controller.toggleCategory('venue');
      await controller.toggleEventType('wedding');
      await controller.sortBy(ListingSort.recent);

      await controller.clearFilters();

      expect(controller.query.categorySlug, isNull);
      expect(controller.query.eventTypeSlug, isNull);
      expect(controller.query.sort, ListingSort.recent);
    });

    test(
      'sem os filtros (falha ao carregá-los) a lista continua utilizável',
      () async {
        catalog.failure = const NetworkFailure();
        await controller.ensureStarted();
        expect(controller.categories, isEmpty);

        catalog.failure = null;
        await controller.showCategory('venue');
        expect(controller.categories, isNotEmpty);
        expect(controller.items, isNotEmpty);
      },
    );
  });
}
