import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/catalog/domain/entities/listing.dart';
import 'package:yvenist/features/client/favorites/data/api_favorites_repository.dart';
import 'package:yvenist/features/client/favorites/data/in_memory_favorites_repository.dart';
import 'package:yvenist/features/client/favorites/domain/favorites_repository.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';

import '../../support/catalog_fixtures.dart';
import '../../support/fake_api.dart';

/// Favoritos em memória que podem falhar ou segurar a resposta.
class ControllableFavorites implements FavoritesRepository {
  final List<Listing> stored = [];
  Object? failure;
  Completer<void>? gate;
  int listCalls = 0;

  Future<void> _maybeWaitAndFail() async {
    await gate?.future;
    final error = failure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<List<Listing>> list() async {
    listCalls++;
    await _maybeWaitAndFail();
    return List.of(stored);
  }

  @override
  Future<void> add(Listing listing) async {
    await _maybeWaitAndFail();
    stored.insert(0, listing);
  }

  @override
  Future<void> remove(String listingId) async {
    await _maybeWaitAndFail();
    stored.removeWhere((listing) => listing.id == listingId);
  }
}

void main() {
  final salao = buildListing(id: 'salao', title: 'Salão');
  final dj = buildListing(id: 'dj', title: 'DJ', category: 'dj');

  group('FavoritesController', () {
    late ControllableFavorites repository;
    late FavoritesController controller;

    setUp(() {
      repository = ControllableFavorites();
      controller = FavoritesController(repository);
    });

    tearDown(() => controller.dispose());

    test('começa vazio e ainda não carregado', () {
      expect(controller.items, isEmpty);
      expect(controller.count, 0);
      expect(controller.hasLoaded, isFalse);
      expect(controller.isFavorite('salao'), isFalse);
    });

    test('ao entrar, carrega os favoritos da conta', () async {
      repository.stored.addAll([salao, dj]);

      await controller.setUser('user-1');

      expect(controller.hasLoaded, isTrue);
      expect(controller.items, [salao, dj]);
      expect(controller.isFavorite('dj'), isTrue);
    });

    test('visitante não consulta o repositório', () async {
      await controller.setUser(null);

      expect(controller.hasLoaded, isTrue);
      expect(controller.items, isEmpty);
      expect(repository.listCalls, 0);
    });

    test('ao sair, esquece os favoritos da conta anterior', () async {
      repository.stored.add(salao);
      await controller.setUser('user-1');

      await controller.setUser(null);

      expect(controller.items, isEmpty);
    });

    test('repetir o mesmo usuário não recarrega', () async {
      await controller.setUser('user-1');
      await controller.setUser('user-1');

      expect(repository.listCalls, 1);
    });

    test('falha na carga fica em loadError e pode ser repetida', () async {
      repository.failure = const NetworkFailure();
      await controller.setUser('user-1');
      expect(controller.loadError, const NetworkFailure().message);
      expect(controller.hasLoaded, isTrue);

      repository.failure = null;
      await controller.load();
      expect(controller.loadError, isNull);
    });

    test('favoritar muda a tela na hora e confirma no repositório', () async {
      await controller.setUser('user-1');
      repository.gate = Completer<void>();

      final pending = controller.toggle(salao);
      await Future<void>.delayed(Duration.zero);
      // Ainda sem resposta do servidor, mas o coração já está marcado.
      expect(controller.isFavorite('salao'), isTrue);
      expect(repository.stored, isEmpty);

      repository.gate!.complete();
      expect(await pending, isTrue);
      expect(repository.stored, [salao]);
    });

    test('desfavoritar remove', () async {
      repository.stored.add(salao);
      await controller.setUser('user-1');

      expect(await controller.toggle(salao), isTrue);

      expect(controller.isFavorite('salao'), isFalse);
      expect(repository.stored, isEmpty);
    });

    test(
      'se o servidor recusar, a tela volta ao que era e mostra o erro',
      () async {
        await controller.setUser('user-1');
        repository.failure = const NetworkFailure();

        final confirmed = await controller.toggle(salao);

        expect(confirmed, isFalse);
        expect(controller.isFavorite('salao'), isFalse);
        expect(controller.error, const NetworkFailure().message);
      },
    );

    test('falha ao desfavoritar devolve o favorito para a lista', () async {
      repository.stored.add(salao);
      await controller.setUser('user-1');
      repository.failure = const ServerFailure();

      expect(await controller.toggle(salao), isFalse);

      expect(controller.isFavorite('salao'), isTrue);
    });

    test(
      'toques repetidos no mesmo anúncio são ignorados enquanto pendente',
      () async {
        await controller.setUser('user-1');
        repository.gate = Completer<void>();

        final first = controller.toggle(salao);
        final second = await controller.toggle(salao);
        repository.gate!.complete();

        expect(second, isFalse);
        expect(await first, isTrue);
        expect(repository.stored, [salao]);
      },
    );

    test('alternar logo após o login espera a carga terminar', () async {
      // Sem essa espera, a resposta da carga (ainda sem o novo favorito)
      // chegaria depois e apagaria o coração que a pessoa acabou de marcar.
      repository.stored.add(dj);
      repository.gate = Completer<void>();
      final loading = controller.setUser('user-1');

      final toggling = controller.toggle(salao);
      repository.gate!.complete();
      await loading;
      await toggling;

      expect(controller.items.map((l) => l.id), ['salao', 'dj']);
    });

    test('avisa os ouvintes quando muda', () async {
      await controller.setUser('user-1');
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.toggle(salao);

      expect(notifications, greaterThan(0));
    });
  });

  group('InMemoryFavoritesRepository', () {
    test('guarda os favoritos separados por conta', () async {
      String? currentUser = 'ana';
      final repository = InMemoryFavoritesRepository(
        currentUserId: () => currentUser,
      );

      await repository.add(salao);
      await repository.add(salao); // repetir não duplica
      await repository.add(dj);
      expect(await repository.list(), [dj, salao]);

      currentUser = 'bruno';
      expect(await repository.list(), isEmpty);

      currentUser = 'ana';
      await repository.remove('salao');
      await repository.remove('nao-existe'); // não é erro
      expect(await repository.list(), [dj]);
    });

    test('sem conta autenticada, falha como não autenticado', () async {
      final repository = InMemoryFavoritesRepository(currentUserId: () => null);

      await expectLater(repository.list(), throwsA(isA<UnauthorizedFailure>()));
    });
  });

  group('ApiFavoritesRepository', () {
    late FakeApi api;
    late ApiFavoritesRepository repository;

    setUp(() {
      api = FakeApi();
      repository = ApiFavoritesRepository(api.client);
    });

    test('lista os anúncios favoritados com o token da conta', () async {
      api.reply('GET', '/favorites', {
        'items': [
          {
            'id': 'salao',
            'title': 'Salão',
            'category': 'venue',
            'neighborhood': null,
            'city': 'Rio de Janeiro',
            'state': 'RJ',
            'price_from_cents': 100000,
            'currency': 'BRL',
            'cover_image_url': null,
            'rating_average': 0.0,
            'rating_count': 0,
          },
        ],
      });

      final favorites = await repository.list();

      expect(favorites.single.id, 'salao');
      expect(api.lastRequest.headers['Authorization'], 'Bearer acesso');
    });

    test('favoritar e remover usam o id do anúncio na rota', () async {
      api
        ..replyEmpty('PUT', '/favorites/salao')
        ..replyEmpty('DELETE', '/favorites/salao');

      await repository.add(salao);
      await repository.remove('salao');

      expect(api.calls, ['PUT /favorites/salao', 'DELETE /favorites/salao']);
    });

    test('limite de favoritos chega como conflito com mensagem', () async {
      api.fail(
        'PUT',
        '/favorites/salao',
        409,
        'favorites_limit_reached',
        'Você atingiu o limite de 500 favoritos.',
      );

      await expectLater(
        repository.add(salao),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.message,
            'message',
            'Você atingiu o limite de 500 favoritos.',
          ),
        ),
      );
    });
  });
}
