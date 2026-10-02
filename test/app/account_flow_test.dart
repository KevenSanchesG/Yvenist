import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';

import '../support/app_harness.dart';

/// Autenticação que não consegue verificar a sessão guardada enquanto
/// [offline], como ao abrir o app sem rede.
class OfflineAtStartAuth extends InMemoryAuthRepository {
  bool offline = true;

  @override
  Future<AppUser?> restoreSession() {
    if (offline) throw const NetworkFailure();
    return super.restoreSession();
  }
}

/// Fluxos de conta: visitante, entrar, criar conta, perfil e segurança.
void main() {
  Future<void> openLoginFromProfile(WidgetTester tester) async {
    await openTab(tester, 'Perfil');
    await tapAndSettle(tester, filledButton('Entrar ou criar conta'));
  }

  Future<void> openRegister(WidgetTester tester) async {
    await openLoginFromProfile(tester);
    await tapAndSettle(tester, find.text('Não tem conta? Criar conta'));
  }

  Future<void> fillRegistration(
    WidgetTester tester, {
    String name = 'Ana Souza',
    String email = 'ana@example.com',
    String password = 'senha-segura-123',
    String? confirmation,
  }) async {
    await enterField(tester, 'Nome completo', name);
    await enterField(tester, 'E-mail', email);
    await enterField(tester, 'Senha', password);
    await enterField(tester, 'Repita a senha', confirmation ?? password);
  }

  group('visitante', () {
    appTest('navega pela vitrine sem ter conta', signedIn: false, (
      tester,
      app,
    ) async {
      expect(find.text('Salão Glamour 8'), findsOneWidget);

      await openTab(tester, 'Explorar');
      expect(find.text('Salão Glamour 8'), findsOneWidget);
    });

    appTest('as abas que exigem conta explicam e convidam a entrar', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Minhas festas');
      expect(find.text('Monte a sua festa'), findsOneWidget);
      expect(filledButton('Entrar ou criar conta'), findsOneWidget);

      await openTab(tester, 'Perfil');
      expect(find.text('Sua conta'), findsOneWidget);
      expect(find.text('Conta Demonstração'), findsNothing);
    }, signedIn: false);

    appTest(
      'favoritar pede login dizendo o motivo, e pode ser cancelado',
      (tester, app) async {
        await tapAndSettle(tester, find.byTooltip('Favoritar Salão Glamour 8'));

        expect(find.text('Entre para salvar seus favoritos.'), findsOneWidget);

        await tapAndSettle(tester, find.byTooltip('Fechar'));
        expect(find.byTooltip('Favoritar Salão Glamour 8'), findsOneWidget);
        expect(app.state.session.isSignedIn, isFalse);
      },
      signedIn: false,
    );

    appTest('depois de entrar, a ação que pediu o login é concluída', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar Salão Glamour 8'));

      await signInWithDemoAccount(tester);

      expect(
        find.byTooltip('Remover Salão Glamour 8 dos favoritos'),
        findsOneWidget,
      );
    }, signedIn: false);

    appTest('adicionar à festa também pede login', (tester, app) async {
      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 8 a uma festa'),
      );
      expect(find.text('Entre para montar a sua festa.'), findsOneWidget);

      await signInWithDemoAccount(tester);

      // Entrou: a escolha da festa abre em seguida.
      expect(find.text('Criar nova festa'), findsOneWidget);
    }, signedIn: false);

    appTest('o atalho de favoritos pede login', (tester, app) async {
      await tapAndSettle(tester, find.byTooltip('Favoritos'));

      expect(find.text('Entre para ver seus favoritos.'), findsOneWidget);
    }, signedIn: false);
  });

  group('entrar', () {
    appTest('o modo demonstração informa a conta de teste', (
      tester,
      app,
    ) async {
      await openLoginFromProfile(tester);

      expect(find.textContaining('Modo demonstração'), findsOneWidget);
      expect(
        find.textContaining(InMemoryAuthRepository.demoEmail),
        findsOneWidget,
      );
    }, signedIn: false);

    appTest('valida os campos antes de enviar', (tester, app) async {
      await openLoginFromProfile(tester);

      await tapAndSettle(tester, filledButton('Entrar'));

      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      await enterField(tester, 'E-mail', 'nao-e-um-email');
      await tapAndSettle(tester, filledButton('Entrar'));
      expect(find.text('E-mail inválido.'), findsOneWidget);
    }, signedIn: false);

    appTest(
      'credenciais erradas mostram o erro e mantêm a pessoa na tela',
      (tester, app) async {
        await openLoginFromProfile(tester);
        await enterField(tester, 'E-mail', InMemoryAuthRepository.demoEmail);
        await enterField(tester, 'Senha', 'senha-errada');

        await tapAndSettle(tester, filledButton('Entrar'));

        expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Entrar'), findsOneWidget);
      },
      signedIn: false,
    );

    appTest('com as credenciais certas, abre o perfil da conta', (
      tester,
      app,
    ) async {
      await openLoginFromProfile(tester);

      await signInWithDemoAccount(tester);

      expect(find.text('Conta Demonstração'), findsOneWidget);
      expect(find.text(InMemoryAuthRepository.demoEmail), findsOneWidget);
    }, signedIn: false);

    appTest('o botão do olho mostra e oculta a senha', (tester, app) async {
      await openLoginFromProfile(tester);
      await enterField(tester, 'Senha', 'segredo');
      EditableText field() => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Senha'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field().obscureText, isTrue);

      await tapAndSettle(tester, find.byTooltip('Mostrar senha'));
      expect(field().obscureText, isFalse);

      await tapAndSettle(tester, find.byTooltip('Ocultar senha'));
      expect(field().obscureText, isTrue);
    }, signedIn: false);

    appTest(
      'sem conseguir verificar a sessão, oferece tentar de novo',
      (tester, app) async {
        // O catálogo continua disponível mesmo sem a sessão verificada.
        expect(find.text('Salão Glamour 8'), findsOneWidget);

        await openTab(tester, 'Perfil');
        expect(
          find.textContaining('Não foi possível verificar a sua sessão'),
          findsOneWidget,
        );

        _auth.offline = false;
        await tapAndSettle(tester, filledButton('Tentar novamente'));

        expect(find.text('Conta Demonstração'), findsOneWidget);
      },
      dependencies: () => demoDependencies(auth: _auth = OfflineAtStartAuth()),
    );
  });

  group('criar conta', () {
    appTest('valida todos os campos e o aceite dos termos', (
      tester,
      app,
    ) async {
      await openRegister(tester);

      await scrollToAndTap(tester, filledButton('Criar conta'));

      expect(find.text('Informe seu nome.'), findsOneWidget);
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Crie uma senha.'), findsOneWidget);
      expect(find.text('Repita a senha.'), findsOneWidget);
      expect(
        find.text('É preciso aceitar para criar a conta.'),
        findsOneWidget,
      );
    }, signedIn: false);

    appTest('recusa senha curta e confirmação diferente', (tester, app) async {
      await openRegister(tester);
      await fillRegistration(tester, password: '1234567');
      await scrollToAndTap(tester, filledButton('Criar conta'));
      expect(find.text('Use pelo menos 8 caracteres.'), findsOneWidget);

      await fillRegistration(tester, confirmation: 'outra-senha-456');
      await scrollToAndTap(tester, filledButton('Criar conta'));
      expect(find.text('As senhas não conferem.'), findsOneWidget);
    }, signedIn: false);

    appTest('sem aceitar os termos a conta não é criada', (tester, app) async {
      await openRegister(tester);
      await fillRegistration(tester);

      await scrollToAndTap(tester, filledButton('Criar conta'));

      expect(
        find.text('É preciso aceitar para criar a conta.'),
        findsOneWidget,
      );
      expect(app.state.session.isSignedIn, isFalse);

      // Marcar o aceite apaga o aviso.
      await scrollToAndTap(tester, find.byType(Checkbox));
      expect(find.text('É preciso aceitar para criar a conta.'), findsNothing);
    }, signedIn: false);

    appTest('cria a conta, entra e mostra o perfil dela', (tester, app) async {
      await openRegister(tester);
      await fillRegistration(tester);
      await scrollToAndTap(tester, find.byType(Checkbox));

      await scrollToAndTap(tester, filledButton('Criar conta'));

      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(app.state.session.user!.email, 'ana@example.com');
    }, signedIn: false);

    appTest('e-mail já cadastrado mostra o motivo', (tester, app) async {
      await openRegister(tester);
      await fillRegistration(tester, email: InMemoryAuthRepository.demoEmail);
      await scrollToAndTap(tester, find.byType(Checkbox));

      await scrollToAndTap(tester, filledButton('Criar conta'));

      expect(find.text('Já existe uma conta com este e-mail.'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Criar conta'), findsOneWidget);
    }, signedIn: false);
  });

  group('perfil', () {
    appTest('mostra a conta, os contadores e o que ainda não existe', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');

      expect(find.text('Conta Demonstração'), findsOneWidget);
      expect(find.text(InMemoryAuthRepository.demoEmail), findsOneWidget);
      expect(find.bySemanticsLabel('0 Festas em planejamento'), findsOneWidget);
      expect(find.bySemanticsLabel('0 Favoritos salvos'), findsOneWidget);
      // Funções previstas aparecem como "Em breve", e não como botões mortos.
      expect(find.text('Em breve'), findsWidgets);
      expect(find.text('Versão 1.0.0'), findsOneWidget);
    });

    appTest('salva os dados pessoais e atualiza o cabeçalho', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Dados Pessoais'));
      // Sem alterações não há o que salvar.
      expect(
        tester.widget<FilledButton>(filledButton('Salvar')).onPressed,
        isNull,
      );

      await enterField(tester, 'Nome completo', 'Maria Clara Souza');
      await enterField(tester, 'Telefone (opcional)', '(21) 99999-8888');
      await tapAndSettle(tester, filledButton('Salvar'));

      expect(find.text('Dados salvos.'), findsOneWidget);
      expect(find.text('Maria Clara Souza'), findsOneWidget);
      expect(app.state.session.user!.phone, '21999998888');
    });

    appTest('telefone sem DDD é recusado', (tester, app) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Dados Pessoais'));

      await enterField(tester, 'Telefone (opcional)', '99999-8888');
      await tapAndSettle(tester, filledButton('Salvar'));

      expect(find.text('Informe o telefone com DDD.'), findsOneWidget);
      expect(app.state.session.user!.phone, isNull);
    });

    appTest('sair com alterações não salvas pede confirmação', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Dados Pessoais'));
      await enterField(tester, 'Nome completo', 'Outro Nome');

      await tapAndSettle(tester, find.byType(BackButton));
      expect(find.text('Descartar alterações?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Continuar editando'));
      expect(find.widgetWithText(AppBar, 'Dados Pessoais'), findsOneWidget);

      await tapAndSettle(tester, find.byType(BackButton));
      await tapAndSettle(tester, find.text('Descartar'));
      expect(find.text('Conta Demonstração'), findsOneWidget);
    });

    appTest('formas de pagamento e termos dizem o que existe hoje', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');

      await scrollToAndTap(tester, find.text('Formas de Pagamento'));
      expect(find.text('Pagamento pelo app em breve'), findsOneWidget);
      await tapAndSettle(tester, find.byType(BackButton));

      await scrollToAndTap(tester, find.text('Termos e Política'));
      expect(find.text('Termos de Uso'), findsOneWidget);
      expect(find.text('Em elaboração'), findsWidgets);
    });

    appTest('sair pede confirmação e volta ao início como visitante', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar Salão Glamour 8'));
      await openTab(tester, 'Perfil');

      await scrollToAndTap(tester, find.text('Sair da conta'));
      expect(find.text('Sair da conta?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Cancelar'));
      expect(app.state.session.isSignedIn, isTrue);

      await scrollToAndTap(tester, find.text('Sair da conta'));
      await tapAndSettle(tester, find.text('Sair'));

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
      expect(app.state.session.isSignedIn, isFalse);
      // Os favoritos eram da conta: para o visitante o coração volta a vazio.
      expect(find.byTooltip('Favoritar Salão Glamour 8'), findsOneWidget);

      await openTab(tester, 'Perfil');
      expect(find.text('Sua conta'), findsOneWidget);
    });
  });

  group('segurança', () {
    Future<void> openSecurity(WidgetTester tester) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Segurança'));
    }

    appTest('lista o que existe e o que está previsto', (tester, app) async {
      await openSecurity(tester);

      expect(find.text('Alterar senha'), findsOneWidget);
      expect(find.text('Autenticação em dois fatores'), findsOneWidget);
      expect(find.text('Em breve'), findsNWidgets(2));
    });

    appTest('trocar a senha exige a senha atual correta', (tester, app) async {
      await openSecurity(tester);
      await tapAndSettle(tester, find.text('Alterar senha'));
      await enterField(tester, 'Senha atual', 'errada');
      await enterField(tester, 'Nova senha', 'nova-senha-456');
      await enterField(tester, 'Repita a nova senha', 'nova-senha-456');

      await tapAndSettle(tester, filledButton('Alterar senha'));
      expect(find.text('Senha atual incorreta.'), findsOneWidget);

      await enterField(
        tester,
        'Senha atual',
        InMemoryAuthRepository.demoPassword,
      );
      await tapAndSettle(tester, filledButton('Alterar senha'));

      expect(find.text('Senha alterada.'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Segurança'), findsOneWidget);
    });

    appTest('a nova senha precisa ser confirmada', (tester, app) async {
      await openSecurity(tester);
      await tapAndSettle(tester, find.text('Alterar senha'));
      await enterField(tester, 'Senha atual', 'qualquer');
      await enterField(tester, 'Nova senha', 'nova-senha-456');
      await enterField(tester, 'Repita a nova senha', 'nova-senha-457');

      await tapAndSettle(tester, filledButton('Alterar senha'));

      expect(find.text('As senhas não conferem.'), findsOneWidget);
    });

    appTest('excluir a conta exige a senha', (tester, app) async {
      await openSecurity(tester);
      await tapAndSettle(tester, find.text('Excluir conta'));
      expect(find.text('Excluir a conta?'), findsOneWidget);
      final confirm = find.widgetWithText(TextButton, 'Excluir conta');

      await tapAndSettle(tester, confirm);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      await enterField(tester, 'Confirme com a sua senha', 'errada');
      await tapAndSettle(tester, confirm);
      expect(find.text('Senha incorreta.'), findsOneWidget);
      expect(app.state.session.isSignedIn, isTrue);

      await tapAndSettle(tester, find.text('Cancelar'));
      expect(find.widgetWithText(AppBar, 'Segurança'), findsOneWidget);
    });

    appTest('com a senha certa, exclui e volta ao início como visitante', (
      tester,
      app,
    ) async {
      await openSecurity(tester);
      await tapAndSettle(tester, find.text('Excluir conta'));
      await enterField(
        tester,
        'Confirme com a sua senha',
        InMemoryAuthRepository.demoPassword,
      );

      await tapAndSettle(
        tester,
        find.widgetWithText(TextButton, 'Excluir conta'),
      );

      expect(find.text('Sua conta foi excluída.'), findsOneWidget);
      expect(find.text('O que vamos comemorar?'), findsOneWidget);
      expect(app.state.session.isSignedIn, isFalse);
    });
  });
}

late OfflineAtStartAuth _auth;
