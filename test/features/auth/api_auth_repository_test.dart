import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/core/storage/token_storage.dart';
import 'package:yvenist/features/auth/data/api_auth_repository.dart';

import '../../support/fake_api.dart';

const Map<String, dynamic> userJson = {
  'id': '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  'email': 'ana@example.com',
  'full_name': 'Ana Souza',
  'phone': '21999998888',
  'birth_date': '1995-05-20',
  'is_admin': false,
  'created_at': '2026-10-01T12:00:00Z',
};

const Map<String, dynamic> tokensJson = {
  'access_token': 'acesso-novo',
  'refresh_token': 'renovacao-nova',
  'token_type': 'bearer',
  'expires_in': 900,
};

void main() {
  late FakeApi api;
  late ApiAuthRepository repository;

  void build({AuthTokens? tokens}) {
    api = FakeApi(tokens: tokens);
    repository = ApiAuthRepository(api.client, api.storage);
  }

  group('restaurar sessão', () {
    test('sem tokens guardados não vai à rede', () async {
      build();

      expect(await repository.restoreSession(), isNull);
      expect(api.requests, isEmpty);
    });

    test('com tokens, busca a conta e converte os campos', () async {
      build(
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      api.reply('GET', '/users/me', userJson);

      final user = await repository.restoreSession();

      expect(user!.id, userJson['id']);
      expect(user.email, 'ana@example.com');
      expect(user.fullName, 'Ana Souza');
      expect(user.phone, '21999998888');
      expect(user.birthDate, DateTime(1995, 5, 20));
      expect(user.isAdmin, isFalse);
      expect(api.lastRequest.headers['Authorization'], 'Bearer a');
    });

    test('sessão que o servidor não aceita mais vira "sem sessão"', () async {
      build(
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      api
        ..fail('GET', '/users/me', 401, 'invalid_token', 'Sessão inválida.')
        ..fail(
          'POST',
          '/auth/refresh',
          401,
          'invalid_refresh_token',
          'Expirou.',
        );

      expect(await repository.restoreSession(), isNull);
      expect(await api.storage.read(), isNull);
    });

    test('sem rede, o erro sobe e os tokens são mantidos', () async {
      build(
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
      api.on('GET', '/users/me', (_) => throw http.ClientException('offline'));

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await api.storage.read(), isNotNull);
    });
  });

  group('entrar e criar conta', () {
    setUp(build);

    test('entrar guarda os tokens e devolve a conta', () async {
      api.reply('POST', '/auth/login', {
        'user': userJson,
        'tokens': tokensJson,
      });

      final user = await repository.signIn(
        email: ' ana@example.com ',
        password: 'senha-segura-123',
      );

      expect(user.fullName, 'Ana Souza');
      expect(api.lastBody, {
        'email': 'ana@example.com',
        'password': 'senha-segura-123',
      });
      expect(api.lastRequest.headers.containsKey('Authorization'), isFalse);
      final stored = await api.storage.read();
      expect(stored!.accessToken, 'acesso-novo');
      expect(stored.refreshToken, 'renovacao-nova');
    });

    test('credenciais inválidas trazem a mensagem do servidor', () async {
      api.fail(
        'POST',
        '/auth/login',
        401,
        'invalid_credentials',
        'E-mail ou senha inválidos.',
      );

      await expectLater(
        repository.signIn(email: 'ana@example.com', password: 'errada'),
        throwsA(
          isA<UnauthorizedFailure>().having(
            (f) => f.message,
            'message',
            'E-mail ou senha inválidos.',
          ),
        ),
      );
      expect(await api.storage.read(), isNull);
    });

    test('criar conta envia o aceite dos termos', () async {
      api.reply('POST', '/auth/register', {
        'user': userJson,
        'tokens': tokensJson,
      }, status: 201);

      await repository.signUp(
        fullName: ' Ana Souza ',
        email: 'ana@example.com',
        password: 'senha-segura-123',
      );

      expect(api.lastBody, {
        'full_name': 'Ana Souza',
        'email': 'ana@example.com',
        'password': 'senha-segura-123',
        'accept_terms': true,
      });
      expect((await api.storage.read())!.accessToken, 'acesso-novo');
    });

    test('e-mail já cadastrado vira conflito com mensagem', () async {
      api.fail(
        'POST',
        '/auth/register',
        409,
        'email_already_registered',
        'Já existe uma conta com este e-mail.',
      );

      await expectLater(
        repository.signUp(
          fullName: 'Ana',
          email: 'ana@example.com',
          password: 'senha-segura-123',
        ),
        throwsA(
          isA<ConflictFailure>().having(
            (f) => f.code,
            'code',
            'email_already_registered',
          ),
        ),
      );
    });
  });

  group('conta autenticada', () {
    setUp(() {
      build(
        tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
      );
    });

    test('sair apaga os tokens e avisa o servidor', () async {
      api.replyEmpty('POST', '/auth/logout');

      await repository.signOut();

      expect(await api.storage.read(), isNull);
      expect(api.lastBody, {'refresh_token': 'r'});
    });

    test('sair funciona mesmo sem rede', () async {
      api.on('POST', '/auth/logout', (_) => throw http.ClientException('x'));

      await repository.signOut();

      expect(await api.storage.read(), isNull);
    });

    test(
      'atualizar dados envia a data sem hora e telefone vazio como null',
      () async {
        api.reply('PATCH', '/users/me', userJson);

        await repository.updateProfile(
          fullName: ' Ana Souza ',
          phone: '  ',
          birthDate: DateTime(1995, 5, 3, 14, 30),
        );

        expect(api.lastBody, {
          'full_name': 'Ana Souza',
          'phone': null,
          'birth_date': '1995-05-03',
        });
        expect(api.lastRequest.headers['Authorization'], 'Bearer a');
      },
    );

    test('trocar a senha passa a usar os tokens novos', () async {
      api.reply('POST', '/users/me/password', tokensJson);

      await repository.changePassword(
        currentPassword: 'antiga-123',
        newPassword: 'nova-senha-456',
      );

      expect(api.lastBody, {
        'current_password': 'antiga-123',
        'new_password': 'nova-senha-456',
      });
      expect((await api.storage.read())!.refreshToken, 'renovacao-nova');
    });

    test('senha atual errada mantém a sessão', () async {
      api.fail(
        'POST',
        '/users/me/password',
        422,
        'wrong_password',
        'Senha atual incorreta.',
      );

      await expectLater(
        repository.changePassword(currentPassword: 'x', newPassword: 'y' * 8),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            'Senha atual incorreta.',
          ),
        ),
      );
      expect((await api.storage.read())!.accessToken, 'a');
    });

    test('excluir a conta confirma com a senha e apaga os tokens', () async {
      api.replyEmpty('POST', '/users/me/delete');

      await repository.deleteAccount(password: 'senha-segura-123');

      expect(api.lastBody, {'password': 'senha-segura-123'});
      expect(await api.storage.read(), isNull);
    });

    test('exclusão recusada não apaga os tokens', () async {
      api.fail(
        'POST',
        '/users/me/delete',
        422,
        'wrong_password',
        'Senha incorreta.',
      );

      await expectLater(
        repository.deleteAccount(password: 'errada'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await api.storage.read(), isNotNull);
    });
  });
}
