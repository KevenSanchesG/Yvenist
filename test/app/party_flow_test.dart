import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';

import '../support/app_harness.dart';

/// Fluxos de favoritos e do Party Maker, a partir dos anúncios da vitrine.
void main() {
  const salao = 'Salão Glamour 8'; // R$ 1.700,00
  const atracao = 'Atração Festiva 8'; // R$ 1.150,00
  const festa = '15 anos da Maria';

  /// Toca no "+" de [listing] e cria uma festa nova com ele.
  Future<void> addToNewParty(
    WidgetTester tester,
    String listing, {
    String title = festa,
  }) async {
    await tapAndSettle(
      tester,
      find.byTooltip('Adicionar $listing a uma festa'),
    );
    await tapAndSettle(tester, find.text('Criar nova festa'));
    await tester.enterText(find.byType(TextField), title);
    await tester.pump();
    await tapAndSettle(tester, filledButton('Criar festa'));
  }

  /// Abre a aba Explorar filtrada em Atrações e põe [atracao] na festa [title].
  Future<void> addAttractionTo(WidgetTester tester, String title) async {
    await openTab(tester, 'Explorar');
    await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));
    await tapAndSettle(
      tester,
      find.byTooltip('Adicionar $atracao a uma festa'),
    );
    await tapAndSettle(tester, find.widgetWithText(ListTile, title));
  }

  group('favoritos', () {
    appTest('favoritar marca o coração e aparece na lista de favoritos', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar $salao'));
      expect(find.byTooltip('Remover $salao dos favoritos'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Favoritos'));

      expect(find.widgetWithText(AppBar, 'Meus Favoritos'), findsOneWidget);
      expect(find.text(salao), findsOneWidget);
    });

    appTest('desfavoritar na lista esvazia a tela, que explica o que fazer', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar $salao'));
      await tapAndSettle(tester, find.byTooltip('Favoritos'));

      await tapAndSettle(
        tester,
        find.byTooltip('Remover $salao dos favoritos'),
      );

      expect(find.text('Você ainda não tem favoritos'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Ver anúncios'));
      expect(find.byTooltip('Favoritar $salao'), findsOneWidget);
    });

    appTest('o perfil conta os favoritos e leva até eles', (tester, app) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar $salao'));
      await openTab(tester, 'Perfil');

      await tapAndSettle(tester, find.bySemanticsLabel('1 Favoritos salvos'));

      expect(find.widgetWithText(AppBar, 'Meus Favoritos'), findsOneWidget);
      expect(find.text(salao), findsOneWidget);
    });

    appTest('o mesmo anúncio fica marcado em todas as telas', (
      tester,
      app,
    ) async {
      await tapAndSettle(tester, find.byTooltip('Favoritar $salao'));

      await openTab(tester, 'Explorar');

      expect(find.byTooltip('Remover $salao dos favoritos'), findsOneWidget);
    });
  });

  group('montar a festa', () {
    appTest('sem festas, a escolha oferece criar a primeira', (
      tester,
      app,
    ) async {
      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar $salao a uma festa'),
      );

      expect(
        find.text('Você ainda não tem festas em planejamento.'),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Criar nova festa'));
      // Sem nome não dá para criar.
      expect(
        tester.widget<FilledButton>(filledButton('Criar festa')).onPressed,
        isNull,
      );

      await tapAndSettle(tester, find.text('Cancelar'));
      expect(app.state.parties.parties, isEmpty);
    });

    appTest('cria a festa com o anúncio e confirma com uma mensagem', (
      tester,
      app,
    ) async {
      await addToNewParty(tester, salao);

      expect(find.text('$salao adicionado a $festa.'), findsOneWidget);
      expect(
        find.byTooltip('$salao já está em uma festa. Adicionar a outra'),
        findsOneWidget,
      );
    });

    appTest('a aba da festa mostra os itens e o total', (tester, app) async {
      await addToNewParty(tester, salao);
      await addAttractionTo(tester, festa);

      await openTab(tester, 'Minhas festas');

      expect(find.widgetWithText(AppBar, festa), findsOneWidget);
      expect(find.text('2 itens selecionados'), findsOneWidget);
      expect(find.text(salao), findsOneWidget);
      expect(find.text(atracao), findsOneWidget);
      expect(find.text(formatBrl(285000)), findsOneWidget);
    });

    appTest('uma festa aceita só um salão, e a escolha explica o motivo', (
      tester,
      app,
    ) async {
      await addToNewParty(tester, salao);
      await waitSnackBarLeave(tester);

      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 7 a uma festa'),
      );
      await tapAndSettle(tester, find.widgetWithText(ListTile, festa));

      expect(
        find.text(
          'Esta festa já tem um salão. Remova o atual para escolher outro.',
        ),
        findsOneWidget,
      );
      // A escolha continua aberta para a pessoa decidir o que fazer.
      expect(find.text('Criar nova festa'), findsOneWidget);
      expect(app.state.parties.parties.single.budget.items, hasLength(1));
    });

    appTest('remover um item atualiza o total', (tester, app) async {
      await addToNewParty(tester, salao);
      await addAttractionTo(tester, festa);
      await openTab(tester, 'Minhas festas');
      await waitSnackBarLeave(tester);

      await tapAndSettle(tester, find.byTooltip('Remover $atracao'));

      expect(find.text('$atracao removido.'), findsOneWidget);
      expect(find.text('1 item selecionado'), findsOneWidget);
      expect(find.text(formatBrl(170000)), findsOneWidget);
    });

    appTest('remover o último item pede confirmação e apaga a festa', (
      tester,
      app,
    ) async {
      await addToNewParty(tester, salao);
      await openTab(tester, 'Minhas festas');
      await waitSnackBarLeave(tester);

      await tapAndSettle(tester, find.byTooltip('Remover $salao'));
      expect(find.text('Remover o último item?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Cancelar'));
      expect(find.text('1 item selecionado'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Remover $salao'));
      await tapAndSettle(tester, find.text('Remover e apagar a festa'));

      expect(find.text('Nenhuma festa aberta'), findsOneWidget);
      expect(app.state.parties.parties, isEmpty);
    });
  });

  group('orçamento', () {
    Future<void> requestQuote(WidgetTester tester) async {
      await addToNewParty(tester, salao);
      await openTab(tester, 'Minhas festas');
      await waitSnackBarLeave(tester);
      await tapAndSettle(tester, filledButton('Solicitar orçamento'));
    }

    appTest('solicitar o orçamento trava a festa e volta para a lista', (
      tester,
      app,
    ) async {
      await requestQuote(tester);

      expect(
        find.text('Orçamento solicitado! A festa fica travada enquanto isso.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppBar, 'Minhas Festas'), findsOneWidget);
      expect(find.text(festa), findsOneWidget);
      expect(find.text('Orçamento solicitado'), findsOneWidget);
      expect(find.text('1 item • ${formatBrl(170000)}'), findsOneWidget);
      expect(app.state.parties.parties.single.status, PartyStatus.locked);
    });

    appTest('festa travada não aceita remoções até ser liberada', (
      tester,
      app,
    ) async {
      await requestQuote(tester);
      await waitSnackBarLeave(tester);
      await tapAndSettle(tester, find.text(festa));

      final remove = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      expect(remove.onPressed, isNull);

      await tapAndSettle(tester, filledButton('Editar festa'));

      expect(find.text('Festa liberada para edição.'), findsOneWidget);
      expect(filledButton('Solicitar orçamento'), findsOneWidget);
      expect(app.state.parties.parties.single.status, PartyStatus.planning);
    });

    appTest('festa travada não aparece na escolha de onde adicionar', (
      tester,
      app,
    ) async {
      await requestQuote(tester);
      await openTab(tester, 'Início');
      await waitSnackBarLeave(tester);

      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 7 a uma festa'),
      );

      expect(find.widgetWithText(ListTile, festa), findsNothing);
      expect(
        find.text('Você ainda não tem festas em planejamento.'),
        findsOneWidget,
      );
    });

    appTest('o perfil conta festas em planejamento e orçamentos', (
      tester,
      app,
    ) async {
      await requestQuote(tester);
      await openTab(tester, 'Início');
      await waitSnackBarLeave(tester);
      await addToNewParty(tester, 'Salão Glamour 7', title: 'Casamento');

      await openTab(tester, 'Perfil');

      expect(find.bySemanticsLabel('1 Festas em planejamento'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Orçamentos solicitados'), findsOneWidget);
    });

    appTest('com mais de uma festa, a aba abre a lista para escolher', (
      tester,
      app,
    ) async {
      await addToNewParty(tester, salao);
      await waitSnackBarLeave(tester);
      await addToNewParty(tester, 'Salão Glamour 7', title: 'Casamento');
      await openTab(tester, 'Perfil');

      await scrollToAndTap(tester, find.text('Minhas Festas'));

      expect(find.widgetWithText(AppBar, 'Minhas Festas'), findsOneWidget);
      expect(find.text(festa), findsOneWidget);
      expect(find.text('Casamento'), findsOneWidget);

      await tapAndSettle(tester, find.text('Casamento'));
      expect(find.widgetWithText(AppBar, 'Casamento'), findsOneWidget);
      expect(find.text('Salão Glamour 7'), findsOneWidget);
    });
  });
}
