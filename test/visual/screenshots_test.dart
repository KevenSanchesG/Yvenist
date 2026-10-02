@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/visual_harness.dart';

/// Gera as imagens de `docs/screenshots` a partir das telas reais do app, em
/// modo demonstração. Veja `dart_test.yaml` para o comando.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await prepareNetworkImages();
  });

  Future<void> capture(WidgetTester tester, String name) async {
    await settleWithImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  }

  /// Um teste que sobe o app em um celular e tira fotos das telas.
  void screenshots(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    bool signedIn = true,
  }) {
    testWidgets(description, (tester) {
      return withFakeNetworkImages(() async {
        usePhoneScreen(tester);
        await pumpYvenistApp(tester, signedIn: signedIn);
        await body(tester);
      });
    });
  }

  screenshots('início', (tester) async {
    await capture(tester, 'home');
  });

  screenshots('explorar', (tester) async {
    await openTab(tester, 'Explorar');

    await capture(tester, 'explorar');
  });

  screenshots('busca', (tester) async {
    await tester.tap(
      find.bySemanticsLabel('Buscar salões, atrações e serviços'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'salão');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    await capture(tester, 'busca');
  });

  screenshots('adicionar à festa e montar a festa', (tester) async {
    await tester.tap(find.byTooltip('Adicionar Salão Glamour 8 a uma festa'));
    await tester.pumpAndSettle();
    await capture(tester, 'adicionar-a-festa');

    await tester.tap(find.text('Criar nova festa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '15 anos da Maria');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar festa'));
    await tester.pumpAndSettle();

    await openTab(tester, 'Explorar');
    await tester.tap(find.text('Atrações'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adicionar Atração Festiva 8 a uma festa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 anos da Maria'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Minhas festas');
    // Espera o aviso "adicionado a..." sair de cima do rodapé.
    await tester.pump(const Duration(seconds: 5));
    await capture(tester, 'party-maker');

    await tester.tap(find.text('Solicitar orçamento'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await capture(tester, 'minhas-festas');
  });

  screenshots('favoritos', (tester) async {
    await tester.tap(find.byTooltip('Favoritar Salão Glamour 8'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();

    await capture(tester, 'favoritos');
  });

  screenshots('perfil', (tester) async {
    await openTab(tester, 'Perfil');
    await capture(tester, 'perfil');

    await tester.tap(find.text('Dados Pessoais'));
    await tester.pumpAndSettle();
    await capture(tester, 'dados-pessoais');
  });

  screenshots('entrar', signedIn: false, (tester) async {
    await openTab(tester, 'Perfil');
    await capture(tester, 'perfil-visitante');

    await tester.tap(find.text('Entrar ou criar conta'));
    await tester.pumpAndSettle();
    await capture(tester, 'entrar');

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pumpAndSettle();
    await capture(tester, 'criar-conta');
  });

  screenshots('anunciar um salão', (tester) async {
    await openTab(tester, 'Perfil');
    await tester.tap(find.text('Tem um salão ou serviço?'));
    await tester.pumpAndSettle();
    await capture(tester, 'fornecedor-convite');

    await tester.tap(find.text('Começar meu anúncio'));
    await tester.pumpAndSettle();
    await capture(tester, 'fornecedor-categorias');

    await tester.tap(find.text('Salão de Festas'));
    await tester.pumpAndSettle();
    // Avançar sem preencher mostra as mensagens de validação.
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await capture(tester, 'fornecedor-validacao');
  });
}
