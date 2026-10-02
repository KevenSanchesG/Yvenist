import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/core/storage/token_storage.dart';

http.Response jsonResponse(
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json', ...headers},
  );
}

http.Response errorResponse(
  int status,
  String code,
  String message, {
  Map<String, dynamic>? details,
  Map<String, String> headers = const {},
}) {
  return jsonResponse(
    {
      'error': {'code': code, 'message': message, 'details': ?details},
    },
    status: status,
    headers: headers,
  );
}

void main() {
  final baseUrl = Uri.parse('https://api.yvenist.test/api/v1');
  const tokens = AuthTokens(
    accessToken: 'acesso-1',
    refreshToken: 'renovacao-1',
  );

  late InMemoryTokenStorage storage;
  late List<http.Request> requests;

  ApiClient clientWith(FutureOr<http.Response> Function(http.Request) handler) {
    return ApiClient(
      baseUrl: baseUrl,
      tokenStorage: storage,
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() {
    storage = InMemoryTokenStorage(tokens);
    requests = [];
  });

  group('requisições', () {
    test('monta a URL com o caminho base e ignora parâmetros vazios', () async {
      final client = clientWith((_) => jsonResponse({'ok': true}));

      await client.get(
        '/catalog/listings',
        query: {'q': 'salão', 'category': null, 'cursor': ''},
      );

      expect(
        requests.single.url.toString(),
        'https://api.yvenist.test/api/v1/catalog/listings?q=sal%C3%A3o',
      );
    });

    test('envia o corpo como JSON em UTF-8', () async {
      final client = clientWith((_) => jsonResponse({'ok': true}));

      await client.post('/auth/login', body: {'email': 'ana@example.com'});

      expect(requests.single.method, 'POST');
      expect(
        requests.single.headers['Content-Type'],
        'application/json; charset=utf-8',
      );
      expect(jsonDecode(requests.single.body), {'email': 'ana@example.com'});
    });

    test('rota pública não envia o token', () async {
      final client = clientWith((_) => jsonResponse([]));

      await client.get('/catalog/categories');

      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('rota autenticada envia o token de acesso', () async {
      final client = clientWith((_) => jsonResponse({'id': '1'}));

      await client.get('/users/me', authenticated: true);

      expect(requests.single.headers['Authorization'], 'Bearer acesso-1');
    });

    test('decodifica o corpo como UTF-8', () async {
      final client = clientWith((_) => jsonResponse({'name': 'Salões'}));

      expect(await client.get('/x'), {'name': 'Salões'});
    });

    test('resposta sem corpo vira null', () async {
      final client = clientWith((_) => http.Response('', 204));

      expect(await client.delete('/favorites/1', authenticated: true), isNull);
    });

    test('rota autenticada sem sessão falha sem ir à rede', () async {
      storage = InMemoryTokenStorage();
      final client = clientWith((_) => jsonResponse({}));

      await expectLater(
        client.get('/users/me', authenticated: true),
        throwsA(isA<UnauthorizedFailure>()),
      );
      expect(requests, isEmpty);
    });
  });

  group('renovação da sessão', () {
    http.Response refreshed([String suffix = '2']) {
      return jsonResponse({
        'user': {'id': '1'},
        'tokens': {
          'access_token': 'acesso-$suffix',
          'refresh_token': 'renovacao-$suffix',
        },
      });
    }

    test('renova o token expirado e repete a requisição', () async {
      final client = clientWith((request) {
        if (request.url.path.endsWith('/auth/refresh')) return refreshed();
        final isFresh = request.headers['Authorization'] == 'Bearer acesso-2';
        return isFresh
            ? jsonResponse({'id': '1'})
            : errorResponse(401, 'invalid_token', 'Sessão inválida.');
      });

      final result = await client.get('/users/me', authenticated: true);

      expect(result, {'id': '1'});
      expect(requests.map((r) => r.url.path.split('/').last), [
        'me',
        'refresh',
        'me',
      ]);
      expect(jsonDecode(requests[1].body), {'refresh_token': 'renovacao-1'});
      expect((await storage.read())!.refreshToken, 'renovacao-2');
    });

    test(
      'várias requisições simultâneas compartilham uma única renovação',
      () async {
        var refreshCalls = 0;
        final client = clientWith((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return refreshed();
          }
          final isFresh = request.headers['Authorization'] == 'Bearer acesso-2';
          return isFresh
              ? jsonResponse({'ok': true})
              : errorResponse(401, 'invalid_token', 'Sessão inválida.');
        });

        await Future.wait([
          client.get('/users/me', authenticated: true),
          client.get('/favorites', authenticated: true),
          client.get('/parties', authenticated: true),
        ]);

        expect(refreshCalls, 1);
      },
    );

    test('sessão recusada pelo servidor é encerrada e avisa o app', () async {
      var expired = 0;
      final client = clientWith(
        (request) => request.url.path.endsWith('/auth/refresh')
            ? errorResponse(401, 'invalid_refresh_token', 'Sessão expirada.')
            : errorResponse(401, 'invalid_token', 'Sessão inválida.'),
      )..onSessionExpired = () => expired++;

      await expectLater(
        client.get('/users/me', authenticated: true),
        throwsA(isA<UnauthorizedFailure>()),
      );

      expect(expired, 1);
      expect(await storage.read(), isNull);
    });

    test('ficar sem rede durante a renovação não encerra a sessão', () async {
      var expired = 0;
      final client = clientWith((request) {
        if (request.url.path.endsWith('/auth/refresh')) {
          throw http.ClientException('sem conexão');
        }
        return errorResponse(401, 'invalid_token', 'Sessão inválida.');
      })..onSessionExpired = () => expired++;

      await expectLater(
        client.get('/users/me', authenticated: true),
        throwsA(isA<NetworkFailure>()),
      );

      expect(expired, 0);
      expect((await storage.read())!.refreshToken, 'renovacao-1');
    });

    test(
      'servidor instável durante a renovação não encerra a sessão',
      () async {
        final client = clientWith(
          (request) => request.url.path.endsWith('/auth/refresh')
              ? http.Response('Bad Gateway', 502)
              : errorResponse(401, 'invalid_token', 'Sessão inválida.'),
        );

        await expectLater(
          client.get('/users/me', authenticated: true),
          throwsA(isA<ServerFailure>()),
        );

        expect(await storage.read(), isNotNull);
      },
    );

    test('401 em rota pública não tenta renovar', () async {
      final client = clientWith(
        (_) => errorResponse(
          401,
          'invalid_credentials',
          'E-mail ou senha inválidos.',
        ),
      );

      await expectLater(
        client.post('/auth/login', body: {'email': 'a@b.c', 'password': 'x'}),
        throwsA(
          isA<UnauthorizedFailure>()
              .having((f) => f.code, 'code', 'invalid_credentials')
              .having(
                (f) => f.message,
                'message',
                'E-mail ou senha inválidos.',
              ),
        ),
      );
      expect(requests, hasLength(1));
    });
  });

  group('tradução de erros', () {
    Future<void> expectFailure<T extends AppFailure>(
      http.Response response, {
      String? code,
      String? message,
    }) async {
      final client = clientWith((_) => response);

      await expectLater(
        client.get('/x'),
        throwsA(
          isA<T>()
              .having((f) => f.code, 'code', code ?? anything)
              .having((f) => f.message, 'message', message ?? anything),
        ),
      );
    }

    test('usa o código e a mensagem enviados pela API', () async {
      await expectFailure<ConflictFailure>(
        errorResponse(409, 'venue_already_selected', 'Já existe um salão.'),
        code: 'venue_already_selected',
        message: 'Já existe um salão.',
      );
      await expectFailure<NotFoundFailure>(
        errorResponse(404, 'party_not_found', 'Festa não encontrada.'),
        code: 'party_not_found',
      );
      await expectFailure<ForbiddenFailure>(
        errorResponse(403, 'forbidden', 'Sem permissão.'),
      );
    });

    test('erro de validação traz as mensagens por campo', () async {
      final client = clientWith(
        (_) => errorResponse(
          422,
          'validation_error',
          'Alguns campos estão inválidos.',
          details: {
            'fields': [
              {'field': 'email', 'message': 'E-mail inválido.'},
              {'field': 'password', 'message': 'Senha curta.'},
            ],
          },
        ),
      );

      await expectLater(
        client.post('/auth/register', body: <String, dynamic>{}),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.fieldErrors, 'fieldErrors', {
                'email': 'E-mail inválido.',
                'password': 'Senha curta.',
              })
              // A mensagem principal é a do primeiro campo, mais útil na tela
              // do que o resumo "Alguns campos estão inválidos."
              .having((f) => f.message, 'message', 'E-mail inválido.'),
        ),
      );
    });

    test('erro de validação sem campos usa a mensagem do servidor', () async {
      final client = clientWith(
        (_) => errorResponse(422, 'wrong_password', 'Senha atual incorreta.'),
      );

      await expectLater(
        client.post('/users/me/password', body: <String, dynamic>{}),
        throwsA(
          isA<ValidationFailure>()
              .having((f) => f.message, 'message', 'Senha atual incorreta.')
              .having((f) => f.code, 'code', 'wrong_password')
              .having((f) => f.fieldErrors, 'fieldErrors', isEmpty),
        ),
      );
    });

    test('limite de requisições informa quando tentar de novo', () async {
      final client = clientWith(
        (_) => errorResponse(
          429,
          'too_many_requests',
          'Muitas tentativas.',
          headers: {'retry-after': '42'},
        ),
      );

      await expectLater(
        client.get('/x'),
        throwsA(
          isA<RateLimitedFailure>().having(
            (f) => f.retryAfter,
            'retryAfter',
            const Duration(seconds: 42),
          ),
        ),
      );
    });

    test('erro do servidor nunca mostra o corpo ao usuário', () async {
      await expectFailure<ServerFailure>(
        http.Response('<html>stack trace interno</html>', 500),
        message:
            'Tivemos um problema do nosso lado. Tente novamente em instantes.',
      );
    });

    test('erro sem corpo no formato esperado usa a mensagem padrão', () async {
      await expectFailure<NotFoundFailure>(
        http.Response('Not Found', 404),
        message: 'Não encontramos o que você procurava.',
      );
    });

    test('resposta de sucesso que não é JSON vira falha do servidor', () async {
      await expectFailure<ServerFailure>(http.Response('<html>', 200));
    });

    test('falha de conexão vira NetworkFailure', () async {
      final client = clientWith(
        (_) => throw http.ClientException('conexão recusada'),
      );

      await expectLater(client.get('/x'), throwsA(isA<NetworkFailure>()));
    });

    test('tempo esgotado vira NetworkFailure', () async {
      final client = ApiClient(
        baseUrl: baseUrl,
        tokenStorage: storage,
        timeout: const Duration(milliseconds: 20),
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return jsonResponse({});
        }),
      );

      await expectLater(client.get('/x'), throwsA(isA<NetworkFailure>()));
    });
  });
}
