import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/client/shared/listing_card.dart';

import '../support/app_harness.dart';
import '../support/review_fixtures.dart';
import '../support/visual_harness.dart';

/// Verificações de acessibilidade nas telas principais.
///
/// O contraste das cores é conferido em `test/core/theme_contrast_test.dart`.
void main() {
  // Com as fontes reais: as larguras dependem do desenho das letras (a fonte
  // padrão dos testes desenha quadrados, bem mais largos).
  setUpAll(loadRealFonts);

  /// As diretrizes que o Flutter sabe conferir sozinho: área de toque de pelo
  /// menos 48x48 e todo controle tocável com rótulo para leitores de tela.
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  }

  Future<void> addSalaoToNewParty(WidgetTester tester) async {
    await scrollToAndTap(
      tester,
      find.byTooltip('Adicionar Salão Glamour 8 a uma festa'),
    );
    await tapAndSettle(tester, find.text('Criar nova festa'));
    await tester.enterText(find.byType(TextField), 'Casamento');
    await tester.pump();
    await tapAndSettle(tester, filledButton('Criar festa'));
    await waitSnackBarLeave(tester);
  }

  Future<void> openHallForm(WidgetTester tester) async {
    await openTab(tester, 'Perfil');
    await scrollToAndTap(tester, find.text('Tem um salão ou serviço?'));
    await scrollToAndTap(tester, filledButton('Começar meu anúncio'));
    await tapAndSettle(tester, find.text('Salão de Festas'));
  }

  group('diretrizes', () {
    appTest('início', (tester, app) async {
      await expectAccessible(tester);
    });

    appTest('explorar', (tester, app) async {
      await openTab(tester, 'Explorar');

      await expectAccessible(tester);
    });

    appTest('busca com resultados', (tester, app) async {
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('Buscar salões, atrações e serviços'),
      );
      await tester.enterText(find.byType(TextField), 'salão');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await expectAccessible(tester);
    });

    appTest('escolha da festa', (tester, app) async {
      await addSalaoToNewParty(tester);
      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 7 a uma festa'),
      );

      await expectAccessible(tester);
    });

    appTest('montagem da festa e lista de festas', (tester, app) async {
      await addSalaoToNewParty(tester);
      await openTab(tester, 'Minhas festas');
      await expectAccessible(tester);

      await tapAndSettle(tester, filledButton('Solicitar orçamento'));
      await waitSnackBarLeave(tester);

      await expectAccessible(tester);
    });

    appTest('favoritos', (tester, app) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar Salão Glamour 8'));
      await tapAndSettle(tester, find.byTooltip('Favoritos'));

      await expectAccessible(tester);
    });

    appTest('perfil, dados pessoais e segurança', (tester, app) async {
      await openTab(tester, 'Perfil');
      await expectAccessible(tester);

      await tapAndSettle(tester, find.text('Dados Pessoais'));
      await expectAccessible(tester);
      await tapAndSettle(tester, find.byType(BackButton));

      await scrollToAndTap(tester, find.text('Segurança'));
      await expectAccessible(tester);
    });

    appTest('entrar e criar conta, com erros na tela', (tester, app) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, filledButton('Entrar ou criar conta'));
      await enterField(tester, 'E-mail', InMemoryAuthRepository.demoEmail);
      await enterField(tester, 'Senha', 'errada');
      await tapAndSettle(tester, filledButton('Entrar'));
      await expectAccessible(tester);

      await tapAndSettle(tester, find.text('Não tem conta? Criar conta'));
      await scrollToAndTap(tester, filledButton('Criar conta'));

      await expectAccessible(tester);
    }, signedIn: false);

    appTest('convite e cadastro do salão', (tester, app) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Tem um salão ou serviço?'));
      await expectAccessible(tester);

      await tapAndSettle(tester, filledButton('Começar meu anúncio'));
      await expectAccessible(tester);

      await tapAndSettle(tester, find.text('Salão de Festas'));
      await tapAndSettle(tester, filledButton('Avançar'));
      await expectAccessible(tester);
    });

    appTest('termos e política', (tester, app) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Termos e Política'));
      await expectAccessible(tester);

      await tapAndSettle(tester, find.text('Termos de Uso'));
      await expectAccessible(tester);
    });

    appTest(
      'fila de análise, com os diálogos de decisão',
      (tester, app) async {
        await openTab(tester, 'Perfil');
        await expectAccessible(tester);

        await scrollToAndTap(tester, find.text('Fila de análise'));
        await expectAccessible(tester);

        await tapAndSettle(tester, find.text('Aprovar'));
        await expectAccessible(tester);
        await tapAndSettle(tester, find.text('Cancelar'));

        await tapAndSettle(tester, find.text('Recusar'));
        await expectAccessible(tester);
        await tapAndSettle(tester, find.text('Cancelar'));

        await tapAndSettle(tester, find.text('Anúncios (2)'));
        await tapAndSettle(tester, find.text('Ver detalhes').first);
        await expectAccessible(tester);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );
  });

  group('leitores de tela', () {
    appTest('os contadores do perfil são botões que podem ser acionados', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');

      expect(
        tester.getSemantics(find.bySemanticsLabel('0 Favoritos salvos')),
        isSemantics(
          label: '0 Favoritos salvos',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });

    appTest('o título de uma faixa é anunciado separado dos cards', (
      tester,
      app,
    ) async {
      final header = find.bySemanticsLabel(
        RegExp('^Salões muito procurados.*Ver todos'),
      );

      expect(
        tester.getSemantics(header),
        isSemantics(isButton: true, isHeader: true, hasTapAction: true),
      );
      // O nó do título cobre só o título, e não a faixa inteira com os cards.
      expect(tester.getSize(header).height, lessThan(120));
    });

    appTest('cada anúncio é descrito em uma frase', (tester, app) async {
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Salão Glamour 8\. A partir de R\$ 1\.700\. Nota 5,0 de 5'),
        ),
        findsOneWidget,
      );
    });

    appTest('a aba atual é anunciada como selecionada', (tester, app) async {
      await openTab(tester, 'Explorar');

      expect(
        tester.getSemantics(tabButton('Explorar')),
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(tabButton('Início')),
        isSemantics(isButton: true, isSelected: false),
      );
      expect(
        tester.getSemantics(tabButton('Minhas festas')),
        isSemantics(isButton: true, isSelected: false, hasTapAction: true),
      );
    });

    appTest('o progresso do cadastro é anunciado por etapa', (
      tester,
      app,
    ) async {
      await openHallForm(tester);

      expect(find.bySemanticsLabel('Etapa 1 de 6'), findsOneWidget);
    });
  });

  group('área de toque', () {
    appTest('o botão central responde ao toque em toda a sua área', (
      tester,
      app,
    ) async {
      final button = tester.getRect(tabButton('Minhas festas'));

      // A parte de cima do botão, que fica acima da barra.
      await tester.tapAt(button.topCenter + const Offset(0, 8));
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma festa aberta'), findsOneWidget);
    });

    appTest('o botão central continua encaixado no topo da barra', (
      tester,
      app,
    ) async {
      final button = tester.getRect(tabButton('Minhas festas'));
      final bar = tester.getRect(tabButton('Início'));

      expect(button.center.dx, 180);
      expect(bar.top - button.top, 19);
      expect(button.size, const Size(64, 64));
    });

    appTest('o seletor de modo do perfil responde em toda a sua altura', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      final option = tester.getRect(
        find.ancestor(
          of: find.text('Modo Fornecedor'),
          matching: find.byType(InkWell),
        ),
      );

      await tester.tapAt(option.bottomCenter - const Offset(0, 4));
      await tester.pumpAndSettle();

      // O toque chegou: o app responde que ainda não há aprovação.
      expect(
        find.textContaining('depois que o seu anúncio é aprovado'),
        findsOneWidget,
      );
    });
  });

  group('letras grandes', () {
    // Com a fonte do sistema no dobro do tamanho, nenhuma tela pode estourar
    // (um estouro de layout faz o teste falhar sozinho) e tudo o que importa
    // continua alcançável rolando.
    const scale = 2.0;

    appTest('início, explorar e festas', (tester, app) async {
      await openTab(tester, 'Explorar');
      await openTab(tester, 'Início');
      await addSalaoToNewParty(tester);
      await openTab(tester, 'Minhas festas');
      expect(find.text('1 item selecionado'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Solicitar orçamento'));
      expect(find.text('Orçamento solicitado'), findsOneWidget);
    }, textScale: scale);

    appTest('com letras 50% maiores o card mostra nome e preço inteiros', (
      tester,
      app,
    ) async {
      // Visto em um aparelho: o card tinha largura fixa, o nome virava
      // "Salão Glam…" e o selo de preço era cortado pela borda.
      final title = tester.renderObject<RenderParagraph>(
        find.text('Salão Glamour 8'),
      );
      expect(title.didExceedMaxLines, isFalse);

      final card = tester.getRect(
        find.ancestor(
          of: find.text('Salão Glamour 8'),
          matching: find.byType(ListingCard),
        ),
      );
      final badge = tester.getRect(find.text('A partir de R\$ 1.700'));
      expect(badge.left, greaterThanOrEqualTo(card.left));
      expect(badge.right, lessThanOrEqualTo(card.right));
    }, textScale: 1.5);

    appTest('busca e favoritos', (tester, app) async {
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('Buscar salões, atrações e serviços'),
      );
      await tester.enterText(find.byType(TextField), 'salão');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.byTooltip('Favoritar Salão Glamour 8'));
      await tapAndSettle(tester, find.byTooltip('Voltar'));

      await tapAndSettle(tester, find.byTooltip('Favoritos'));

      expect(find.text('Salão Glamour 8'), findsOneWidget);
    }, textScale: scale);

    appTest('perfil e telas da conta', (tester, app) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Dados Pessoais'));
      await tapAndSettle(tester, find.byType(BackButton));
      await scrollToAndTap(tester, find.text('Formas de Pagamento'));
      await tapAndSettle(tester, find.byType(BackButton));
      await scrollToAndTap(tester, find.text('Termos e Política'));
      await tapAndSettle(tester, find.text('Política de Privacidade'));
      await tapAndSettle(tester, find.byType(BackButton));
      await tapAndSettle(tester, find.byType(BackButton));
      await scrollToAndTap(tester, find.text('Segurança'));
      await tapAndSettle(tester, find.text('Alterar senha'));

      expect(find.text('Senha atual'), findsOneWidget);
    }, textScale: scale);

    appTest(
      'entrar e criar conta',
      (tester, app) async {
        await openTab(tester, 'Perfil');
        await tapAndSettle(tester, filledButton('Entrar ou criar conta'));
        await scrollToAndTap(tester, find.text('Não tem conta? Criar conta'));
        await scrollToAndTap(tester, filledButton('Criar conta'));

        expect(find.text('Informe seu nome.'), findsOneWidget);
      },
      signedIn: false,
      textScale: scale,
    );

    appTest(
      'fila de análise, diálogos e detalhes do anúncio',
      (tester, app) async {
        await openTab(tester, 'Perfil');
        await scrollToAndTap(tester, find.text('Fila de análise'));

        await tapAndSettle(tester, find.text('Aprovar'));
        await tapAndSettle(tester, find.text('Cancelar'));
        await tapAndSettle(tester, find.text('Recusar'));
        await tapAndSettle(tester, find.text('Recusar').last);
        expect(find.text('Explique o motivo da recusa.'), findsOneWidget);
        await tapAndSettle(tester, find.text('Cancelar'));

        await tapAndSettle(tester, find.textContaining('Anúncios'));
        await tapAndSettle(tester, find.text('Ver detalhes').first);

        expect(
          find.textContaining('Capacidade', findRichText: true),
          findsOneWidget,
        );
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
      textScale: scale,
    );

    appTest('convite e cadastro do salão, até a revisão', (tester, app) async {
      await openHallForm(tester);
      Future<void> next() => tapAndSettle(tester, filledButton('Avançar'));

      // Com letras grandes uma etapa pode não caber na tela, e os campos de
      // baixo só existem depois de rolar a lista dela.
      Future<void> fill(String label, String text) async {
        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, label),
          120,
          scrollable: find
              .descendant(
                of: find.byType(Form),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await enterField(tester, label, text);
      }

      await fill('CPF do responsável', '529.982.247-25');
      await fill('Nome completo', 'Maria Oliveira');
      await next();
      await fill('Nome do salão', 'Espaço Crystal');
      await fill(
        'Descrição',
        'Salão amplo, climatizado, com cozinha equipada.',
      );
      await fill('Cidade', 'Salvador');
      await scrollToAndTap(
        tester,
        find.byType(DropdownButtonFormField<String>),
      );
      await tapAndSettle(tester, find.text('BA').last);
      await next();
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Casamentos'));
      await next();
      await next();
      await fill('Preço a partir de', '2500');
      await next();

      expect(find.text('Confira antes de enviar'), findsOneWidget);
      expect(filledButton('Enviar anúncio'), findsOneWidget);
    }, textScale: scale);
  });
}
