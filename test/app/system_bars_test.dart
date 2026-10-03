import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_palette.dart';
import 'package:yvenist/features/client/shared/listing_tile.dart';

import '../support/app_harness.dart';
import '../support/party_harness.dart';
import '../support/review_fixtures.dart';
import '../support/visual_harness.dart';

/// O app desenha a tela inteira, inclusive por baixo da barra de status e da
/// barra de navegação do sistema, que são transparentes. Nada do que importa
/// pode ficar escondido por baixo delas.
void main() {
  // Em um aparelho: 24 de barra de status e 48 de barra de navegação (a de
  // três botões, a mais alta).
  const statusBar = 24.0;
  const navigationBar = 48.0;

  /// Dá ao teste as barras de um aparelho de verdade. Sem isso a tela do
  /// teste não tem barra nenhuma, e nada disto aparece.
  Future<void> useSystemBars(WidgetTester tester) async {
    const padding = FakeViewPadding(
      top: statusBar * phonePixelRatio,
      bottom: navigationBar * phonePixelRatio,
    );
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    await tester.pumpAndSettle();
  }

  /// Onde a barra de navegação do sistema começa, de cima para baixo.
  double navigationBarTop(WidgetTester tester) {
    return tester.view.physicalSize.height / tester.view.devicePixelRatio -
        navigationBar;
  }

  /// Rola a lista que está na tela até o fim, por mais longa que seja.
  Future<void> scrollToEnd(WidgetTester tester) async {
    // Só as que rolam para baixo: um campo de texto também tem, por dentro,
    // uma área que rola (para o lado).
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;
    final position = tester.state<ScrollableState>(scrollable).position;
    double before;
    do {
      before = position.pixels;
      await tester.drag(scrollable, const Offset(0, -600));
      await tester.pumpAndSettle();
    } while (position.pixels > before);
  }

  group('barra de status', () {
    appTest('no perfil, o conteúdo não passa por baixo do relógio', (
      tester,
      app,
    ) async {
      // Regressão: o cabeçalho do perfil vai por baixo da barra de status, e
      // o resto da tela rolava atrás dele: "MINHA CONTA" passava por baixo do
      // relógio. Visto em um aparelho.
      await useSystemBars(tester);
      await openTab(tester, 'Perfil');
      final backdrop = find.byKey(const ValueKey('status-bar-backdrop'));

      // No topo, o cabeçalho escuro fica por baixo do relógio, que é branco.
      expect(tester.widget<AnimatedOpacity>(backdrop).opacity, 0);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.light,
      );

      await scrollToEnd(tester);

      // Rolando, um fundo na cor da tela cobre a barra de status e o relógio
      // volta a ter a cor do tema.
      expect(tester.widget<AnimatedOpacity>(backdrop).opacity, 1);
      expect(tester.getSize(backdrop).height, statusBar);
      expect(
        SystemChrome.latestStyle!.statusBarIconBrightness,
        Brightness.dark,
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 5000),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedOpacity>(backdrop).opacity, 0);
    });
  });

  group('barra de navegação do sistema', () {
    appTest('é transparente nos dois temas: cada tela cuida do que fica ali', (
      tester,
      app,
    ) async {
      await useSystemBars(tester);
      expect(SystemChrome.latestStyle!.systemNavigationBarColor!.a, 0);
      expect(
        SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
        Brightness.dark,
      );

      await useDarkTheme(tester, app);

      expect(SystemChrome.latestStyle!.systemNavigationBarColor!.a, 0);
      expect(
        SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
        Brightness.light,
      );
    });

    appTest('em uma tela empilhada, com barra no topo, continua transparente', (
      tester,
      app,
    ) async {
      // A barra do topo de uma tela pede só o estilo da barra de status; o da
      // barra de navegação vem de volta do app inteiro.
      await useSystemBars(tester);
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Aparência'));

      final style = SystemChrome.latestStyle!;
      expect(style.systemNavigationBarColor!.a, 0);
      expect(style.statusBarIconBrightness, Brightness.dark);

      await tapAndSettle(tester, find.text('Escuro'));

      final dark = SystemChrome.latestStyle!;
      expect(dark.systemNavigationBarColor!.a, 0);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(dark.statusBarIconBrightness, Brightness.light);
    });

    appTest(
      'onde a tela não vai por baixo dela, fica na cor das superfícies do '
      'app',
      (tester, app) async {
        // É o que acontece no Android 9 ou mais antigo. Transparente, a barra
        // mostraria o fundo da janela, que é branco: com o tema escuro, botões
        // brancos sobre fundo branco. (Sem `useSystemBars`, a tela do teste
        // termina acima da barra, como nesses aparelhos.)
        expect(
          SystemChrome.latestStyle!.systemNavigationBarColor,
          AppPalette.light.surface,
        );

        await useDarkTheme(tester, app);

        final style = SystemChrome.latestStyle!;
        expect(style.systemNavigationBarColor, AppPalette.dark.surface);
        expect(style.systemNavigationBarIconBrightness, Brightness.light);
      },
    );

    appTest('no convite ao fornecedor, escuro nos dois temas, os botões do '
        'sistema ficam brancos', (tester, app) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Tem um salão ou serviço?'));

      // Sem a tela por baixo da barra, ela fica na cor escura do fundo...
      final opaque = SystemChrome.latestStyle!;
      expect(opaque.systemNavigationBarIconBrightness, Brightness.light);
      expect(opaque.systemNavigationBarColor, AppColors.vendorGradient.first);

      // ...e, com a tela por baixo, é a foto escurecida que aparece ali.
      await useSystemBars(tester);
      final transparent = SystemChrome.latestStyle!;
      expect(transparent.systemNavigationBarIconBrightness, Brightness.light);
      expect(transparent.systemNavigationBarColor!.a, 0);
    });

    appTest('a barra do app guarda o espaço dela, e os botões ficam acima', (
      tester,
      app,
    ) async {
      await useSystemBars(tester);

      for (final tab in ['Início', 'Explorar', 'Chat', 'Perfil']) {
        expect(
          tester.getRect(tabButton(tab)).bottom,
          lessThanOrEqualTo(navigationBarTop(tester)),
          reason: tab,
        );
      }
    });

    appTest('o fim de um texto longo para acima dela', (tester, app) async {
      // Regressão: a lista ia até a borda de baixo sem contar a barra do
      // sistema, e as últimas linhas ficavam por baixo dos botões.
      await useSystemBars(tester);
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Termos e Política'));
      await tapAndSettle(tester, find.text('Termos de Uso'));
      await tester.pumpAndSettle();

      await scrollToEnd(tester);

      // A última linha dos Termos de Uso.
      expect(
        tester
            .getRect(find.textContaining('Responsável pela plataforma'))
            .bottom,
        lessThanOrEqualTo(navigationBarTop(tester)),
      );
    });

    appTest('o último resultado de uma busca para acima dela', (
      tester,
      app,
    ) async {
      await useSystemBars(tester);
      await tapAndSettle(
        tester,
        find.bySemanticsLabel('Buscar salões, atrações e serviços'),
      );
      await tester.enterText(find.byType(TextField), 'salão');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      await scrollToEnd(tester);

      expect(
        tester.getRect(find.byType(ListingTile).last).bottom,
        lessThanOrEqualTo(navigationBarTop(tester)),
      );
    });

    appTest(
      'na fila de análise, o último cartão para acima dela',
      (tester, app) async {
        await useSystemBars(tester);
        await openTab(tester, 'Perfil');
        await scrollToAndTap(tester, find.text('Fila de análise'));
        await tapAndSettle(tester, find.text('Anúncios (2)'));

        await scrollToEnd(tester);

        expect(
          tester.getRect(find.text('Publicar').last).bottom,
          lessThanOrEqualTo(navigationBarTop(tester)),
        );
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
      // Com dois cartões a fila só passa do tamanho da tela com letras grandes.
      textScale: 2,
    );

    appTest('no cadastro do salão, o rodapé vai até a borda e os botões ficam '
        'acima dela', (tester, app) async {
      // Regressão: o rodapé parava acima da barra do sistema e sobrava, por
      // baixo dela, uma faixa da cor do fundo da tela.
      await useSystemBars(tester);
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Tem um salão ou serviço?'));
      await tapAndSettle(tester, filledButton('Começar meu anúncio'));
      await tapAndSettle(tester, find.text('Salão de Festas'));

      final next = tester.getRect(filledButton('Avançar'));
      expect(next.bottom, lessThanOrEqualTo(navigationBarTop(tester)));

      // O fundo do rodapé é o que aparece por baixo da barra do sistema.
      final footer = find
          .ancestor(
            of: filledButton('Avançar'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getRect(footer).bottom,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
    });

    appTest('na configuração de um item, o rodapé vai até a borda e o botão '
        'fica acima dela', (tester, app) async {
      await useSystemBars(tester);
      await startAddingToNewParty(tester, 'Salão Glamour 8', title: 'Festa');

      final add = tester.getRect(filledButton('Adicionar à festa'));
      expect(add.bottom, lessThanOrEqualTo(navigationBarTop(tester)));

      // O fundo do rodapé é o que aparece por baixo da barra do sistema.
      final footer = find
          .ancestor(
            of: filledButton('Adicionar à festa'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        tester.getRect(footer).bottom,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
    });

    appTest(
      'nos dados do evento, o botão de salvar para acima dela',
      (tester, app) async {
        await useSystemBars(tester);
        await openTab(tester, 'Minhas festas');
        await scrollToAndTap(tester, filledButton('Criar festa'));
        expect(find.widgetWithText(AppBar, 'Nova festa'), findsOneWidget);

        await scrollToEnd(tester);

        expect(
          tester.getRect(filledButton('Criar festa')).bottom,
          lessThanOrEqualTo(navigationBarTop(tester)),
        );
      },
      // Com letras grandes o formulário passa do tamanho da tela.
      textScale: 2,
    );

    appTest('no histórico da festa, o último registro para acima dela', (
      tester,
      app,
    ) async {
      await useSystemBars(tester);
      final party = await seedParty(tester, app, title: 'Festa');
      await app.state.parties.requestQuote(party.id);
      await answerAll(app, cents: 100000);
      await app.state.parties.load();
      await openTab(tester, 'Minhas festas');
      await choosePartyOption(tester, 'Histórico da festa');

      await scrollToEnd(tester);

      // O mais antigo fica por último: o pedido de orçamento.
      expect(
        tester.getRect(find.textContaining('1ª rodada').last).bottom,
        lessThanOrEqualTo(navigationBarTop(tester)),
      );
    }, textScale: 2);

    appTest('nos pedidos de orçamento, as respostas do último pedido ficam '
        'acima dela', (tester, app) async {
      await useSystemBars(tester);
      final party = await seedParty(tester, app, title: 'Festa');
      await app.state.parties.requestQuote(party.id);
      await openTab(tester, 'Minhas festas');
      await tapAndSettle(tester, find.text('Responder como fornecedor (demo)'));

      await scrollToEnd(tester);

      expect(
        tester.getRect(find.text('Informar valor').last).bottom,
        lessThanOrEqualTo(navigationBarTop(tester)),
      );
    });

    appTest(
      'o atalho de aparência do visitante fica acima dela, mesmo com '
      'letras grandes',
      (tester, app) async {
        await useSystemBars(tester);
        await openTab(tester, 'Perfil');
        await tapAndSettle(tester, find.text('Aparência'));

        await scrollToEnd(tester);

        expect(
          tester
              .getRect(find.textContaining('A escolha vale para este aparelho'))
              .bottom,
          lessThanOrEqualTo(navigationBarTop(tester)),
        );
      },
      signedIn: false,
      textScale: 2,
    );
  });
}
