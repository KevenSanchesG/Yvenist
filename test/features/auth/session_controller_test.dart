import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';

/// Repositório cuja restauração de sessão falha, como quando não há rede.
class OfflineAuthRepository implements AuthRepository {
  bool offline = true;

  @override
  Future<AppUser?> restoreSession() async {
    if (offline) throw const NetworkFailure();
    return InMemoryAuthRepository.demoUser;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late InMemoryAuthRepository repository;
  late SessionController session;

  setUp(() {
    repository = InMemoryAuthRepository(startSignedIn: false);
    session = SessionController(repository);
  });

  tearDown(() => session.dispose());

  Future<bool> signInDemo() {
    return session.signIn(
      email: InMemoryAuthRepository.demoEmail,
      password: InMemoryAuthRepository.demoPassword,
    );
  }

  group('restaurar', () {
    test('começa verificando a sessão', () {
      expect(session.status, SessionStatus.restoring);
      expect(session.isSignedIn, isFalse);
    });

    test('sem sessão guardada, fica como visitante', () async {
      await session.restore();

      expect(session.status, SessionStatus.signedOut);
      expect(session.user, isNull);
    });

    test('com sessão guardada, fica autenticado', () async {
      final signedIn = SessionController(InMemoryAuthRepository());
      addTearDown(signedIn.dispose);

      await signedIn.restore();

      expect(signedIn.status, SessionStatus.signedIn);
      expect(signedIn.user, InMemoryAuthRepository.demoUser);
    });

    test(
      'sem conseguir verificar, sinaliza e permite tentar de novo',
      () async {
        final offlineRepository = OfflineAuthRepository();
        final offline = SessionController(offlineRepository);
        addTearDown(offline.dispose);

        await offline.restore();
        expect(offline.status, SessionStatus.restoreFailed);
        expect(offline.isSignedIn, isFalse);

        offlineRepository.offline = false;
        await offline.restore();
        expect(offline.status, SessionStatus.signedIn);
      },
    );
  });

  group('entrar', () {
    test('com credenciais válidas, autentica', () async {
      expect(await signInDemo(), isTrue);

      expect(session.status, SessionStatus.signedIn);
      expect(session.user!.email, InMemoryAuthRepository.demoEmail);
      expect(session.error, isNull);
    });

    test(
      'com credenciais inválidas, expõe a falha e segue visitante',
      () async {
        await session.restore();

        final signedIn = await session.signIn(
          email: 'ana@example.com',
          password: 'errada',
        );

        expect(signedIn, isFalse);
        expect(session.error, 'E-mail ou senha inválidos.');
        expect(session.failure, isA<UnauthorizedFailure>());
        expect(session.status, SessionStatus.signedOut);
        expect(session.isBusy, isFalse);
      },
    );

    test('uma nova tentativa limpa o erro anterior', () async {
      await session.signIn(email: 'ana@example.com', password: 'errada');

      await signInDemo();

      expect(session.error, isNull);
    });

    test('fica ocupado durante a operação e avisa os ouvintes', () async {
      final busyStates = <bool>[];
      session.addListener(() => busyStates.add(session.isBusy));

      await signInDemo();

      expect(busyStates.first, isTrue);
      expect(busyStates.last, isFalse);
    });
  });

  group('criar conta', () {
    test('cria e já autentica', () async {
      final created = await session.signUp(
        fullName: 'Ana Souza',
        email: 'ana@example.com',
        password: 'senha-segura-123',
      );

      expect(created, isTrue);
      expect(session.user!.fullName, 'Ana Souza');
    });

    test('e-mail repetido expõe a mensagem do conflito', () async {
      final created = await session.signUp(
        fullName: 'Outra pessoa',
        email: InMemoryAuthRepository.demoEmail,
        password: 'senha-segura-123',
      );

      expect(created, isFalse);
      expect(session.error, 'Já existe uma conta com este e-mail.');
      expect(session.isSignedIn, isFalse);
    });
  });

  group('conta autenticada', () {
    setUp(signInDemo);

    test('sair volta a ser visitante', () async {
      await session.signOut();

      expect(session.status, SessionStatus.signedOut);
      expect(session.user, isNull);
    });

    test('atualizar dados troca o usuário exposto', () async {
      final saved = await session.updateProfile(
        fullName: 'Nome Novo',
        phone: '21999998888',
        birthDate: null,
      );

      expect(saved, isTrue);
      expect(session.user!.fullName, 'Nome Novo');
      expect(session.user!.phone, '21999998888');
    });

    test('trocar a senha com a atual errada mantém a sessão', () async {
      final changed = await session.changePassword(
        currentPassword: 'errada',
        newPassword: 'nova-senha-456',
      );

      expect(changed, isFalse);
      expect(session.error, 'Senha atual incorreta.');
      expect(session.isSignedIn, isTrue);
    });

    test('excluir a conta encerra a sessão', () async {
      final deleted = await session.deleteAccount(
        password: InMemoryAuthRepository.demoPassword,
      );

      expect(deleted, isTrue);
      expect(session.status, SessionStatus.signedOut);
    });

    test('exclusão recusada mantém a conta e a sessão', () async {
      expect(await session.deleteAccount(password: 'errada'), isFalse);
      expect(session.isSignedIn, isTrue);
      expect(session.error, 'Senha incorreta.');
    });

    test('sessão expirada no servidor desloga', () {
      var notifications = 0;
      session.addListener(() => notifications++);

      session.handleSessionExpired();

      expect(session.status, SessionStatus.signedOut);
      expect(notifications, 1);
    });

    test('clearError apaga a falha exibida', () async {
      await session.changePassword(
        currentPassword: 'errada',
        newPassword: 'x' * 8,
      );

      session.clearError();

      expect(session.error, isNull);
    });
  });

  test('sessão expirada sem ninguém autenticado não notifica', () async {
    await session.restore();
    var notifications = 0;
    session.addListener(() => notifications++);

    session.handleSessionExpired();

    expect(notifications, 0);
  });

  test('operação que termina depois do dispose não quebra', () async {
    final disposable = SessionController(InMemoryAuthRepository());

    final pending = disposable.restore();
    disposable.dispose();

    await expectLater(pending, completes);
  });
}
