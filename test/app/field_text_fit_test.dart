import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/party_harness.dart';
import '../support/visual_harness.dart';

/// O que só as letras de verdade mostram: se o texto de um campo cabe.
///
/// Os outros testes desenham um quadrado no lugar de cada letra, mais largo
/// que a letra. Servem para achar o que estoura a tela, mas não dizem se um
/// texto que é cortado com reticências (o rótulo, a ajuda ou o erro de um
/// campo) aparece inteiro em um aparelho. Aqui a fonte é a do app, na largura
/// de um celular comum (360).
void main() {
  const salao = 'Salão Glamour 8';
  const decoracao = 'Decoração Encanto 8';
  const festa = '15 anos da Maria';

  setUpAll(loadRealFonts);

  /// Os rótulos, as ajudas, as dicas e os erros de campo que estão na tela e
  /// foram cortados.
  List<String> cutFieldTexts() {
    final texts = find.descendant(
      of: find.byType(InputDecorator),
      matching: find.byType(RichText),
    );
    return [
      for (final element in texts.evaluate())
        if ((element.renderObject! as RenderParagraph).didExceedMaxLines)
          (element.widget as RichText).text.toPlainText(),
    ];
  }

  void expectFieldTextsFit() {
    expect(cutFieldTexts(), isEmpty, reason: 'texto de campo cortado');
  }

  /// Abre a caixa de pedidos do fornecedor, com uma festa já solicitada.
  Future<void> openQuoteInbox(WidgetTester tester, TestApp app) async {
    final party = await seedParty(tester, app, title: festa);
    await app.state.parties.requestQuote(party.id);
    await openTab(tester, 'Minhas festas');
    await tapAndSettle(tester, find.text('Responder como fornecedor (demo)'));
  }

  appTest('configuração de um salão, vazia e com os erros na tela', (
    tester,
    app,
  ) async {
    await startAddingToNewParty(tester, salao, title: festa);
    expectFieldTextsFit();

    await tapAndSettle(tester, filledButton('Adicionar à festa'));
    expectFieldTextsFit();

    // Um serviço cobrado por hora abre o campo da duração dele.
    await scrollToAndTap(tester, find.text('Animação da casa'));
    expectFieldTextsFit();
  });

  appTest('configuração de uma decoração', (tester, app) async {
    await seedParty(tester, app, title: festa, withAttraction: false);
    await openTab(tester, 'Minhas festas');
    await revealAndTap(tester, find.byTooltip('Adicionar $decoracao à festa'));
    expectFieldTextsFit();

    await tapAndSettle(tester, filledButton('Adicionar à festa'));
    expectFieldTextsFit();
  });

  appTest('dados do evento, ao criar e ao editar', (tester, app) async {
    await openTab(tester, 'Minhas festas');
    await tapAndSettle(tester, filledButton('Criar festa'));
    expectFieldTextsFit();

    await tapAndSettle(tester, filledButton('Criar festa'));
    expectFieldTextsFit();
  });

  appTest('diálogo de valor do fornecedor, com o erro na tela', (
    tester,
    app,
  ) async {
    // Regressão: no diálogo, mais estreito que a tela, o rótulo do campo da
    // mensagem aparecia cortado ("Mensagem para o cliente (op…") e o erro do
    // valor também ("Informe o valor, por exemplo 1500 ou 1...."). Visto em
    // um Android.
    await openQuoteInbox(tester, app);
    await tapAndSettle(tester, find.text('Informar valor').first);
    expectFieldTextsFit();

    await tapAndSettle(tester, filledButton('Enviar valor'));
    expect(
      find.text('Informe o valor, por exemplo 1500 ou 1.500,00.'),
      findsOneWidget,
    );
    expectFieldTextsFit();
  });

  appTest('diálogos de pedir alteração e de recusar, com o erro na tela', (
    tester,
    app,
  ) async {
    await openQuoteInbox(tester, app);

    await tapAndSettle(tester, find.text('Pedir alteração').first);
    await tapAndSettle(tester, filledButton('Pedir alteração'));
    expectFieldTextsFit();
    await tapAndSettle(tester, find.text('Cancelar'));

    await tapAndSettle(tester, find.text('Recusar').first);
    await tapAndSettle(tester, filledButton('Recusar pedido'));
    expectFieldTextsFit();
  });
}
