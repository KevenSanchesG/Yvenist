import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';

void main() {
  late InMemoryAuthRepository repository;

  setUp(() => repository = InMemoryAuthRepository(startSignedIn: false));

  Future<void> signUpAna() {
    return repository.signUp(
      fullName: 'Ana Souza',
      email: 'Ana@Example.com',
      password: 'senha-segura-123',
    );
  }

  test('por padrão o modo demonstração já abre autenticado', () async {
    final demo = InMemoryAuthRepository();

    expect(await demo.restoreSession(), InMemoryAuthRepository.demoUser);
    expect(demo.currentUserId, 'demo-user');
  });

  test('pode começar como visitante', () async {
    expect(await repository.restoreSession(), isNull);
    expect(repository.currentUserId, isNull);
  });

  group('entrar', () {
    test('aceita as credenciais da conta de demonstração', () async {
      final user = await repository.signIn(
        email: ' DEMO@yvenist.app ',
        password: InMemoryAuthRepository.demoPassword,
      );

      expect(user.email, InMemoryAuthRepository.demoEmail);
      expect(await repository.restoreSession(), user);
    });

    test('senha errada e e-mail desconhecido falham do mesmo jeito', () async {
      final wrongPassword = repository.signIn(
        email: InMemoryAuthRepository.demoEmail,
        password: 'errada',
      );
      final unknownEmail = repository.signIn(
        email: 'ninguem@example.com',
        password: 'errada',
      );

      for (final attempt in [wrongPassword, unknownEmail]) {
        await expectLater(
          attempt,
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
      }
      expect(repository.currentUserId, isNull);
    });
  });

  group('criar conta', () {
    test('cria, autentica e normaliza o e-mail', () async {
      await signUpAna();

      final user = await repository.restoreSession();
      expect(user!.email, 'ana@example.com');
      expect(user.fullName, 'Ana Souza');
      expect(repository.currentUserId, user.id);
    });

    test('não aceita o mesmo e-mail duas vezes', () async {
      await signUpAna();

      await expectLater(
        repository.signUp(
          fullName: 'Outra Ana',
          email: 'ANA@example.com',
          password: 'outra-senha-123',
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

    test('valida os dados como o servidor faria', () async {
      await expectLater(
        repository.signUp(fullName: 'Ana', email: 'ana', password: '12345678'),
        throwsA(isA<ValidationFailure>()),
      );
      await expectLater(
        repository.signUp(
          fullName: 'Ana',
          email: 'ana@example.com',
          password: 'curta',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('cada conta nova recebe um id diferente', () async {
      await signUpAna();
      final first = repository.currentUserId;
      await repository.signUp(
        fullName: 'Bruno Lima',
        email: 'bruno@example.com',
        password: 'senha-segura-123',
      );

      expect(repository.currentUserId, isNot(first));
    });
  });

  group('conta autenticada', () {
    setUp(signUpAna);

    test('sair encerra a sessão', () async {
      await repository.signOut();

      expect(await repository.restoreSession(), isNull);
    });

    test(
      'atualiza os dados pessoais e guarda só os dígitos do telefone',
      () async {
        final updated = await repository.updateProfile(
          fullName: '  Ana Maria Souza ',
          phone: '(21) 99999-8888',
          birthDate: DateTime(1995, 5, 20),
        );

        expect(updated.fullName, 'Ana Maria Souza');
        expect(updated.phone, '21999998888');
        expect(updated.birthDate, DateTime(1995, 5, 20));
        expect(await repository.restoreSession(), same(updated));
      },
    );

    test('telefone vazio limpa o campo', () async {
      await repository.updateProfile(
        fullName: 'Ana Souza',
        phone: '21999998888',
        birthDate: null,
      );

      final updated = await repository.updateProfile(
        fullName: 'Ana Souza',
        phone: '  ',
        birthDate: null,
      );

      expect(updated.phone, isNull);
    });

    test('trocar a senha exige a senha atual', () async {
      await expectLater(
        repository.changePassword(
          currentPassword: 'errada',
          newPassword: 'nova-senha-456',
        ),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.code,
            'code',
            'wrong_password',
          ),
        ),
      );

      await repository.changePassword(
        currentPassword: 'senha-segura-123',
        newPassword: 'nova-senha-456',
      );
      await repository.signOut();
      final user = await repository.signIn(
        email: 'ana@example.com',
        password: 'nova-senha-456',
      );
      expect(user.fullName, 'Ana Souza');
    });

    test('excluir a conta exige a senha e impede novo login', () async {
      await expectLater(
        repository.deleteAccount(password: 'errada'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(repository.currentUserId, isNotNull);

      await repository.deleteAccount(password: 'senha-segura-123');

      expect(repository.currentUserId, isNull);
      await expectLater(
        repository.signIn(
          email: 'ana@example.com',
          password: 'senha-segura-123',
        ),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });
  });

  test('a conta de teste, se excluída, volta zerada', () async {
    // A tela de entrada do modo demonstração anuncia essas credenciais: elas
    // precisam continuar funcionando, mas sem os dados da conta apagada.
    final demo = InMemoryAuthRepository();
    final before = demo.currentUserId;

    await demo.deleteAccount(password: InMemoryAuthRepository.demoPassword);
    expect(demo.currentUserId, isNull);

    final user = await demo.signIn(
      email: InMemoryAuthRepository.demoEmail,
      password: InMemoryAuthRepository.demoPassword,
    );
    expect(user.fullName, InMemoryAuthRepository.demoUser.fullName);
    expect(user.id, isNot(before));
  });

  test('operações de conta sem sessão falham como não autenticado', () async {
    await expectLater(
      repository.updateProfile(fullName: 'X', phone: null, birthDate: null),
      throwsA(isA<UnauthorizedFailure>()),
    );
    await expectLater(
      repository.deleteAccount(password: 'x'),
      throwsA(isA<UnauthorizedFailure>()),
    );
  });
}
