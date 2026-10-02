import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';

import '../support/app_harness.dart';
import '../support/catalog_fixtures.dart';

/// Fluxos de quem só está olhando o catálogo: vitrine, explorar e busca.
void main() {
  group('vitrine', () {
    appTest('mostra a busca, os atalhos e as faixas de anúncios', (
      tester,
      app,
    ) async {
      expect(find.text('O que vamos comemorar?'), findsOneWidget);
      expect(find.bySemanticsLabel('Ver Salões'), findsOneWidget);
      expect(find.text('Salões muito procurados'), findsOneWidget);
      expect(find.text('Salão Glamour 8'), findsOneWidget);
    });

    appTest('um atalho de categoria abre Explorar já filtrado', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.bySemanticsLabel('Ver Atrações'));

      expect(find.widgetWithText(AppBar, 'Explorar'), findsOneWidget);
      expect(find.text('Atração Festiva 8'), findsOneWidget);
      expect(find.textContaining('Salão Glamour'), findsNothing);
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Atrações'),
      );
      expect(chip.selected, isTrue);
    });

    appTest('o título de uma faixa leva a todos os anúncios da categoria', (
      tester,
      app,
    ) async {
      await tapAndSettle(
        tester,
        find.bySemanticsLabel(RegExp('^Salões muito procurados.*Ver todos')),
      );

      expect(find.widgetWithText(AppBar, 'Explorar'), findsOneWidget);
      expect(find.text('Salão Glamour 8'), findsOneWidget);
      expect(find.textContaining('Atração Festiva'), findsNothing);
    });

    appTest(
      'falha ao carregar oferece tentar de novo',
      (tester, app) async {
        expect(find.text('Não foi possível carregar'), findsOneWidget);
        expect(find.text(const NetworkFailure().message), findsOneWidget);
        expect(find.text('Salão Glamour 8'), findsNothing);

        _catalog.failure = null;
        await tapAndSettle(tester, filledButton('Tentar novamente'));

        expect(find.text('Salão Glamour 8'), findsOneWidget);
      },
      dependencies: () => demoDependencies(catalog: _failingCatalog()),
    );
  });

  group('navegação', () {
    appTest('cada aba abre a sua tela', (tester, app) async {
      await openTab(tester, 'Explorar');
      expect(find.widgetWithText(AppBar, 'Explorar'), findsOneWidget);

      await openTab(tester, 'Chat');
      expect(find.text('Conversas em breve'), findsOneWidget);

      await openTab(tester, 'Perfil');
      expect(find.text('Conta Demonstração'), findsOneWidget);

      await openTab(tester, 'Minhas festas');
      expect(find.text('Nenhuma festa aberta'), findsOneWidget);

      await openTab(tester, 'Início');
      expect(find.text('O que vamos comemorar?'), findsOneWidget);
    });

    appTest('o voltar do sistema, fora do início, leva ao início', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Explorar');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Explorar'), findsNothing);
    });

    appTest('as setas de voltar das abas levam ao início', (tester, app) async {
      await openTab(tester, 'Chat');

      await tapAndSettle(tester, find.byTooltip('Voltar ao início'));

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
    });

    appTest('notificações mostra o estado vazio real', (tester, app) async {
      await tapAndSettle(tester, find.byTooltip('Notificações'));

      expect(find.text('Nenhuma notificação'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Voltar'));
      expect(find.text('O que vamos comemorar?'), findsOneWidget);
    });
  });

  group('explorar', () {
    appTest('lista o catálogo e filtra por categoria e tipo de evento', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Explorar');
      expect(find.text('Salão Glamour 8'), findsOneWidget);

      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));
      expect(find.text('Atração Festiva 8'), findsOneWidget);
      expect(find.textContaining('Salão Glamour'), findsNothing);

      // Atrações não atendem casamentos: a combinação não tem resultado.
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Casamentos'));
      expect(find.text('Nenhum anúncio encontrado'), findsOneWidget);
      expect(find.text('Tente outra combinação de filtros.'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Limpar filtros'));
      expect(find.text('Salão Glamour 8'), findsOneWidget);
    });

    appTest('tocar de novo no filtro ativo desliga o filtro', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Explorar');
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));

      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));

      expect(find.text('Salão Glamour 8'), findsOneWidget);
    });

    appTest('ordena pelo menor preço', (tester, app) async {
      await openTab(tester, 'Explorar');

      await tapAndSettle(tester, find.byTooltip('Ordenar: Mais procurados'));
      await tapAndSettle(tester, find.text('Menor preço'));

      // A mais barata do catálogo de demonstração.
      expect(find.text('Decoração Encanto 1'), findsOneWidget);
      expect(find.byTooltip('Ordenar: Menor preço'), findsOneWidget);
    });

    appTest('rolar até o fim busca a próxima página', (tester, app) async {
      await openTab(tester, 'Explorar');
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Salões'));
      expect(find.text('Salão Glamour 1'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Salão Glamour 1'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first,
      );

      expect(find.text('Salão Glamour 1'), findsOneWidget);
    });

    appTest(
      'falha ao carregar oferece tentar de novo',
      (tester, app) async {
        _catalog.failure = const NetworkFailure();
        await openTab(tester, 'Explorar');
        expect(find.text('Não foi possível carregar'), findsOneWidget);

        _catalog.failure = null;
        await tapAndSettle(tester, filledButton('Tentar novamente'));

        expect(find.text('Salão Glamour 8'), findsOneWidget);
      },
      dependencies: () => demoDependencies(catalog: _workingCatalog()),
    );
  });

  group('busca', () {
    Future<void> openSearch(WidgetTester tester) {
      return tapAndSettle(
        tester,
        find.bySemanticsLabel('Buscar salões, atrações e serviços'),
      );
    }

    appTest('abre com sugestões e busca enquanto a pessoa digita', (
      tester,
      app,
    ) async {
      await openSearch(tester);
      expect(find.text('Sugestões'), findsOneWidget);

      // Sem acento e em minúsculas: a busca encontra do mesmo jeito.
      await tester.enterText(find.byType(TextField), 'salao glamour 3');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Salão Glamour 3'), findsOneWidget);
      expect(find.text('Sugestões'), findsNothing);
    });

    appTest('uma letra só ainda não dispara a busca', (tester, app) async {
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 's');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Sugestões'), findsOneWidget);
    });

    appTest('tocar em uma sugestão busca por ela', (tester, app) async {
      await openSearch(tester);

      await tapAndSettle(tester, find.widgetWithText(ActionChip, 'Decorações'));

      expect(find.text('Decoração Encanto 8'), findsOneWidget);
    });

    appTest('explica quando não encontra nada e permite limpar', (
      tester,
      app,
    ) async {
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'xyzxyz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Nada encontrado para "xyzxyz"'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Limpar busca'));
      expect(find.text('Sugestões'), findsOneWidget);
    });

    appTest('voltar retorna à vitrine', (tester, app) async {
      await openSearch(tester);

      await tapAndSettle(tester, find.byTooltip('Voltar'));

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
    });
  });
}

// O catálogo controlável do teste em andamento: o teste liga e desliga a falha
// depois de o app já estar na tela.
late ControllableCatalog _catalog;

ControllableCatalog _workingCatalog() => _catalog = ControllableCatalog();

ControllableCatalog _failingCatalog() {
  return _workingCatalog()..failure = const NetworkFailure();
}
