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
      expect(find.text('Você ainda não tem festas'), findsOneWidget);

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

    appTest('o filtro de categoria marcado troca o ícone pelo visto', (
      tester,
      app,
    ) async {
      // Regressão: o filtro marcado mantinha o ícone da categoria e o Material
      // desenhava o visto por cima dele, com um disco cinza no meio.
      await openTab(tester, 'Explorar');
      FilterChip chip(String label) =>
          tester.widget(find.widgetWithText(FilterChip, label));
      expect(chip('Atrações').avatar, isNotNull);

      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));

      expect(chip('Atrações').selected, isTrue);
      expect(chip('Atrações').avatar, isNull);
      expect(chip('Salões').avatar, isNotNull);
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

      // O menor valor anunciado no catálogo de demonstração: a ordem compara o
      // número do anúncio, seja ele por pessoa, por hora ou pelo serviço.
      expect(find.text('Buffet Sabor & Festa 1'), findsOneWidget);
      expect(find.text(r'R$ 55 por pessoa'), findsOneWidget);
      expect(find.byTooltip('Ordenar: Menor preço'), findsOneWidget);
    });

    /// Toca no filtro de uma categoria que pode estar fora da tela: a faixa de
    /// filtros rola para o lado e só monta o que está visível.
    Future<void> filterBy(WidgetTester tester, String category) async {
      final chip = find.widgetWithText(FilterChip, category);
      await tester.scrollUntilVisible(
        chip,
        120,
        scrollable: find
            .descendant(
              of: find.bySemanticsLabel('Filtrar por categoria'),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      // Montado não é o mesmo que inteiro na tela: traz o filtro para dentro
      // antes de tocar.
      await scrollToAndTap(tester, chip);
    }

    appTest('cada anúncio diz a que o preço se refere', (tester, app) async {
      await openTab(tester, 'Explorar');

      await filterBy(tester, 'Atrações');
      expect(find.text(r'R$ 270 por hora'), findsOneWidget);

      await filterBy(tester, 'Decorações');
      // A mais procurada das decorações não publica preço: nenhum número
      // aparece no lugar.
      expect(find.text('Sob consulta'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Decoração Encanto 8\. Sob consulta\.')),
        findsOneWidget,
      );
    });

    appTest('um anúncio sob consulta entra em uma festa sem inventar um '
        'valor', (tester, app) async {
      await openTab(tester, 'Explorar');
      await filterBy(tester, 'Decorações');

      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Decoração Encanto 8 a uma festa'),
      );
      await tapAndSettle(tester, find.text('Criar nova festa'));
      await tester.enterText(find.byType(TextField), 'Festa da Ana');
      await tester.pump();
      await tapAndSettle(tester, filledButton('Criar festa'));

      // A configuração mostra "Sob consulta" no lugar do preço e da
      // estimativa: nunca um R$ 0,00.
      expect(find.text('Sob consulta'), findsNWidgets(2));
      expect(find.textContaining(r'R$'), findsNothing);

      await enterField(tester, 'Tema', 'Safari');
      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      final party = app.state.parties.parties.single;
      expect(party.budget.items.single.pricing.isOnRequest, isTrue);
      expect(party.estimate.unpricedItems, 1);
      expect(party.estimate.total.cents, 0);
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
