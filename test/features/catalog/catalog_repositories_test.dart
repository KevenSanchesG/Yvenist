import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/catalog/data/api_catalog_repository.dart';
import 'package:yvenist/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';

import '../../support/fake_api.dart';

List<String> titles(ListingPage page) => [for (final l in page.items) l.title];

void main() {
  group('Listing', () {
    test('o rótulo de local prefere o bairro', () {
      const withNeighborhood = Listing(
        id: '1',
        title: 'Salão',
        categorySlug: 'venue',
        neighborhood: 'Campo Grande',
        city: 'Rio de Janeiro',
        state: 'RJ',
        priceFromCents: 100000,
      );
      const withoutNeighborhood = Listing(
        id: '2',
        title: 'Salão',
        categorySlug: 'venue',
        city: 'Niterói',
        state: 'RJ',
        priceFromCents: 100000,
      );

      expect(withNeighborhood.locationLabel, 'Campo Grande, RJ');
      expect(withoutNeighborhood.locationLabel, 'Niterói, RJ');
      expect(withNeighborhood.hasRatings, isFalse);
    });

    test('anúncios são iguais pelo id', () {
      const a = Listing(
        id: '1',
        title: 'Nome antigo',
        categorySlug: 'venue',
        city: 'Rio',
        state: 'RJ',
        priceFromCents: 1,
      );
      const b = Listing(
        id: '1',
        title: 'Nome novo',
        categorySlug: 'venue',
        city: 'Rio',
        state: 'RJ',
        priceFromCents: 2,
      );

      expect(a, b);
      expect({a, b}, hasLength(1));
    });
  });

  group('ListingQuery', () {
    test('copyWith altera, mantém e limpa filtros', () {
      const query = ListingQuery(text: 'salão', categorySlug: 'venue');

      final sorted = query.copyWith(sort: ListingSort.priceAsc);
      expect(sorted.text, 'salão');
      expect(sorted.categorySlug, 'venue');
      expect(sorted.sort, ListingSort.priceAsc);

      final cleared = query.copyWith(categorySlug: () => null);
      expect(cleared.categorySlug, isNull);
      expect(cleared.text, 'salão');
    });

    test('consultas iguais são iguais', () {
      expect(
        const ListingQuery(text: 'dj', sort: ListingSort.recent),
        const ListingQuery(text: 'dj', sort: ListingSort.recent),
      );
      expect(
        const ListingQuery(text: 'dj'),
        isNot(const ListingQuery(text: 'dj', categorySlug: 'dj')),
      );
    });
  });

  group('InMemoryCatalogRepository', () {
    late InMemoryCatalogRepository catalog;

    setUp(() => catalog = InMemoryCatalogRepository());

    test('traz as categorias e os tipos de evento de demonstração', () async {
      final categories = await catalog.categories();
      final eventTypes = await catalog.eventTypes();

      expect(categories.first.slug, 'venue');
      expect(categories.map((c) => c.name), contains('Decorações'));
      expect(eventTypes.map((e) => e.slug), contains('wedding'));
    });

    test('a busca ignora acentos, maiúsculas e espaços extras', () async {
      for (final term in [
        'salao glamour 3',
        'SALÃO GLAMOUR 3',
        '  salão   glamour 3 ',
      ]) {
        final page = await catalog.search(ListingQuery(text: term));
        expect(titles(page), ['Salão Glamour 3'], reason: 'termo: "$term"');
      }
    });

    test(
      'a busca também encontra pelo bairro e pelo nome da categoria',
      () async {
        final byNeighborhood = await catalog.search(
          const ListingQuery(text: 'barra da tijuca'),
          limit: 50,
        );
        final byCategory = await catalog.search(
          const ListingQuery(text: 'decoracoes'),
          limit: 50,
        );

        expect(byNeighborhood.items, hasLength(8));
        expect(
          byNeighborhood.items.every((l) => l.categorySlug == 'attraction'),
          isTrue,
        );
        expect(
          byCategory.items.every((l) => l.categorySlug == 'decoration'),
          isTrue,
        );
      },
    );

    test('filtra por categoria e por tipo de evento', () async {
      final venues = await catalog.search(
        const ListingQuery(categorySlug: 'venue'),
        limit: 50,
      );
      final kidsParties = await catalog.search(
        const ListingQuery(eventTypeSlug: 'kids_party'),
        limit: 50,
      );

      expect(venues.items, hasLength(8));
      expect(venues.items.every((l) => l.categorySlug == 'venue'), isTrue);
      expect(kidsParties.items.map((l) => l.categorySlug).toSet(), {
        'attraction',
        'decoration',
      });
    });

    test('ordena por popularidade, preço e data', () async {
      Future<List<String>> firstTitles(ListingSort sort) async {
        final page = await catalog.search(
          ListingQuery(categorySlug: 'venue', sort: sort),
          limit: 2,
        );
        return titles(page);
      }

      expect(await firstTitles(ListingSort.popular), [
        'Salão Glamour 8',
        'Salão Glamour 7',
      ]);
      expect(await firstTitles(ListingSort.priceAsc), [
        'Salão Glamour 1',
        'Salão Glamour 2',
      ]);
      expect(await firstTitles(ListingSort.priceDesc), [
        'Salão Glamour 8',
        'Salão Glamour 7',
      ]);
      expect(await firstTitles(ListingSort.recent), [
        'Salão Glamour 1',
        'Salão Glamour 2',
      ]);
    });

    test('pagina por cursor sem repetir nem pular itens', () async {
      final seen = <String>[];
      String? cursor;
      var pages = 0;
      do {
        final page = await catalog.search(
          const ListingQuery(),
          cursor: cursor,
          limit: 10,
        );
        seen.addAll(page.items.map((l) => l.id));
        cursor = page.nextCursor;
        pages++;
      } while (cursor != null);

      expect(pages, 4);
      expect(seen, hasLength(32));
      expect(seen.toSet(), hasLength(32));
    });

    test('a última página não tem cursor', () async {
      final page = await catalog.search(
        const ListingQuery(categorySlug: 'venue'),
        limit: 8,
      );

      expect(page.items, hasLength(8));
      expect(page.hasMore, isFalse);
    });

    test('busca sem resultado devolve página vazia', () async {
      final page = await catalog.search(
        const ListingQuery(text: 'inexistente'),
      );

      expect(page.items, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('normalizeSearchText remove acentos, caixa e espaços', () {
      expect(
        normalizeSearchText('  Salão   de FESTAS São João '),
        'salao de festas sao joao',
      );
    });
  });

  group('ApiCatalogRepository', () {
    late FakeApi api;
    late ApiCatalogRepository catalog;

    const listingJson = {
      'id': '6d4c9d3f-0da9-4f27-9bb8-b158a61bdea5',
      'title': 'Salão Glamour 8',
      'category': 'venue',
      'neighborhood': 'Campo Grande',
      'city': 'Rio de Janeiro',
      'state': 'RJ',
      'price_from_cents': 170000,
      'currency': 'BRL',
      'cover_image_url': 'https://example.com/capa.jpg',
      'rating_average': 5.0,
      'rating_count': 127,
    };

    setUp(() {
      api = FakeApi(tokens: null);
      catalog = ApiCatalogRepository(api.client);
    });

    test('converte o anúncio e o cursor da resposta', () async {
      api.reply('GET', '/catalog/listings', {
        'items': [listingJson],
        'next_cursor': 'abc',
      });

      final page = await catalog.search(const ListingQuery());

      final listing = page.items.single;
      expect(listing.id, listingJson['id']);
      expect(listing.title, 'Salão Glamour 8');
      expect(listing.categorySlug, 'venue');
      expect(listing.locationLabel, 'Campo Grande, RJ');
      expect(listing.priceFromCents, 170000);
      expect(listing.coverImageUrl, 'https://example.com/capa.jpg');
      expect(listing.ratingAverage, 5.0);
      expect(listing.ratingCount, 127);
      expect(page.nextCursor, 'abc');
      expect(page.hasMore, isTrue);
    });

    test('aceita nota inteira e campos opcionais ausentes', () async {
      api.reply('GET', '/catalog/listings', {
        'items': [
          {
            'id': '1',
            'title': 'DJ',
            'category': 'dj',
            'neighborhood': null,
            'city': 'Niterói',
            'state': 'RJ',
            'price_from_cents': 80000,
            'cover_image_url': null,
            'rating_average': 4,
            'rating_count': 0,
          },
        ],
        'next_cursor': null,
      });

      final listing = (await catalog.search(const ListingQuery())).items.single;

      expect(listing.ratingAverage, 4.0);
      expect(listing.coverImageUrl, isNull);
      expect(listing.locationLabel, 'Niterói, RJ');
      expect(listing.currency, 'BRL');
    });

    test('envia filtros, ordenação, limite e cursor como parâmetros', () async {
      api.reply('GET', '/catalog/listings', {
        'items': <Object>[],
        'next_cursor': null,
      });

      await catalog.search(
        const ListingQuery(
          text: ' salão ',
          categorySlug: 'venue',
          eventTypeSlug: 'wedding',
          sort: ListingSort.priceAsc,
        ),
        cursor: 'proxima',
        limit: 5,
      );

      expect(api.lastRequest.url.queryParameters, {
        'q': 'salão',
        'category': 'venue',
        'event_type': 'wedding',
        'sort': 'price_asc',
        'limit': '5',
        'cursor': 'proxima',
      });
      // O catálogo é público: não envia token.
      expect(api.lastRequest.headers.containsKey('Authorization'), isFalse);
    });

    test('filtros vazios não viram parâmetros', () async {
      api.reply('GET', '/catalog/listings', {
        'items': <Object>[],
        'next_cursor': null,
      });

      await catalog.search(const ListingQuery());

      expect(api.lastRequest.url.queryParameters, {
        'sort': 'popular',
        'limit': '20',
      });
    });

    test('categorias são buscadas uma vez e depois reaproveitadas', () async {
      api.reply('GET', '/catalog/categories', [
        {'slug': 'venue', 'name': 'Salões', 'icon': 'venue'},
      ]);

      final first = await catalog.categories();
      final second = await catalog.categories();

      expect(first.single.name, 'Salões');
      expect(first.single.iconKey, 'venue');
      expect(second, same(first));
      expect(api.requests, hasLength(1));
    });

    test(
      'uma falha não fica guardada: a próxima chamada tenta de novo',
      () async {
        api.on(
          'GET',
          '/catalog/event-types',
          (_) => throw http.ClientException('x'),
        );
        await expectLater(catalog.eventTypes(), throwsA(isA<NetworkFailure>()));

        api.reply('GET', '/catalog/event-types', [
          {'slug': 'wedding', 'name': 'Casamentos'},
        ]);
        final eventTypes = await catalog.eventTypes();

        expect(eventTypes.single.slug, 'wedding');
      },
    );
  });
}
