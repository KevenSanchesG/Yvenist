@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../support/app_harness.dart';
import '../support/party_harness.dart';
import '../support/review_fixtures.dart';
import '../support/visual_harness.dart';

/// As telas que também têm captura no tema escuro em `docs/screenshots`
/// (`<nome>-escuro.png`). As outras só são geradas no escuro com
/// `--dart-define=ALL_DARK=true`, em `build/screenshots-escuro/`, para
/// conferir à mão sem pôr tudo no repositório.
const Set<String> _darkInDocs = {
  'home',
  'explorar',
  'party-maker',
  'party-orcamento',
  'perfil',
  'entrar',
  'fornecedor-validacao',
  'admin-fornecedores',
  'aparencia',
};

const bool _allDark = bool.fromEnvironment('ALL_DARK');

const String _partyTitle = '15 anos da Maria';

/// A data da festa das capturas. Fixa, para a imagem não mudar a cada vez que
/// é gerada; longe, porque a festa só aceita uma data no futuro.
final DateTime _eventDate = DateTime(2030, 6, 15, 19);

/// Gera as imagens de `docs/screenshots` a partir das telas reais do app, em
/// modo demonstração. Veja `dart_test.yaml` para o comando.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await prepareNetworkImages();
  });

  group('tema claro', () => _screens(ThemeMode.light));
  group('tema escuro', () => _screens(ThemeMode.dark));
}

void _screens(ThemeMode mode) {
  final isDark = mode == ThemeMode.dark;

  Future<void> capture(WidgetTester tester, String name) async {
    final String path;
    if (!isDark) {
      path = '../../docs/screenshots/$name.png';
    } else if (_darkInDocs.contains(name)) {
      path = '../../docs/screenshots/$name-escuro.png';
    } else if (_allDark) {
      path = '../../build/screenshots-escuro/$name.png';
    } else {
      return;
    }

    await settleWithImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  }

  /// Um teste que sobe o app em um celular e tira fotos das telas.
  void screenshots(
    String description,
    Future<void> Function(WidgetTester tester, TestApp app) body, {
    bool signedIn = true,
    AppDependencies Function()? dependencies,
  }) {
    testWidgets(description, (tester) {
      return withFakeNetworkImages(() {
        return withRealShadows(() async {
          usePhoneScreen(tester);
          final app = await pumpYvenistApp(
            tester,
            signedIn: signedIn,
            dependencies: dependencies?.call(),
          );
          if (isDark) {
            await app.state.theme.select(ThemeMode.dark);
            await tester.pumpAndSettle();
          }
          await body(tester, app);
        });
      });
    });
  }

  screenshots('início', (tester, app) async {
    await capture(tester, 'home');
  });

  screenshots('explorar', (tester, app) async {
    await openTab(tester, 'Explorar');

    await capture(tester, 'explorar');
  });

  screenshots('busca', (tester, app) async {
    await tester.tap(
      find.bySemanticsLabel('Buscar salões, atrações e serviços'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'salão');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    await capture(tester, 'busca');
  });

  screenshots('adicionar à festa e configurar o item', (tester, app) async {
    await tester.tap(find.byTooltip('Adicionar Salão Glamour 8 a uma festa'));
    await tester.pumpAndSettle();
    await capture(tester, 'adicionar-a-festa');

    await tester.tap(find.text('Criar nova festa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _partyTitle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar festa'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Número de convidados', '80');
    await tester.pumpAndSettle();
    await capture(tester, 'configurar-item');
  });

  screenshots('a festa: montagem, orçamento recebido e lista', (
    tester,
    app,
  ) async {
    final party = await seedParty(
      tester,
      app,
      title: _partyTitle,
      eventDate: _eventDate,
    );
    await openTab(tester, 'Minhas festas');
    await capture(tester, 'party-maker');

    // Os fornecedores respondem, e a festa mostra o orçamento ao lado da
    // estimativa.
    await app.state.parties.requestQuote(party.id);
    final inbox = app.dependencies.quoteInbox;
    final answers = [
      VendorResponse.quote(
        Money.fromCents(180000),
        message: 'Inclui a montagem das mesas.',
      ),
      VendorResponse.quote(Money.fromCents(15000)),
      VendorResponse.quote(Money.fromCents(100000)),
    ];
    for (final (index, item) in party.budget.items.indexed) {
      await inbox.respond(item.id.value, answers[index]);
    }
    await app.state.parties.load();
    await tester.pumpAndSettle();
    await capture(tester, 'party-orcamento');

    await seedParty(
      tester,
      app,
      title: 'Casamento da Ana',
      venueId: 'demo-venue-7',
      withAttraction: false,
      eventDate: _eventDate.add(const Duration(days: 90)),
      guests: 150,
    );
    app.state.parties.clearActiveParty();
    await tester.pumpAndSettle();
    await capture(tester, 'minhas-festas');
  });

  screenshots('pedidos de orçamento (fornecedor)', (tester, app) async {
    final party = await seedParty(
      tester,
      app,
      title: _partyTitle,
      eventDate: _eventDate,
    );
    await app.state.parties.requestQuote(party.id);
    await openTab(tester, 'Minhas festas');
    await tapAndSettle(tester, find.text('Responder como fornecedor (demo)'));

    await capture(tester, 'pedidos-de-orcamento');
  });

  screenshots('favoritos', (tester, app) async {
    await tester.tap(find.byTooltip('Favoritar Salão Glamour 8'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favoritos'));
    await tester.pumpAndSettle();

    await capture(tester, 'favoritos');
  });

  screenshots('perfil', (tester, app) async {
    await openTab(tester, 'Perfil');
    await capture(tester, 'perfil');

    await tester.tap(find.text('Dados Pessoais'));
    await tester.pumpAndSettle();
    await capture(tester, 'dados-pessoais');
  });

  screenshots('aparência', (tester, app) async {
    await openTab(tester, 'Perfil');
    await scrollToAndTap(tester, find.text('Aparência'));

    await capture(tester, 'aparencia');
  });

  screenshots('termos de uso', (tester, app) async {
    await openTab(tester, 'Perfil');
    await scrollToAndTap(tester, find.text('Termos e Política'));
    await tapAndSettle(tester, find.text('Termos de Uso'));

    await capture(tester, 'termos-de-uso');
  });

  screenshots(
    'fila de análise (administração)',
    (tester, app) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Fila de análise'));
      await capture(tester, 'admin-fornecedores');

      await tapAndSettle(tester, find.text('Anúncios (2)'));
      await capture(tester, 'admin-anuncios');
    },
    dependencies: () => adminDependencies(sampleReviewQueue()),
  );

  screenshots('entrar', signedIn: false, (tester, app) async {
    await openTab(tester, 'Perfil');
    await capture(tester, 'perfil-visitante');

    await tester.tap(find.text('Entrar ou criar conta'));
    await tester.pumpAndSettle();
    await capture(tester, 'entrar');

    await tester.tap(find.text('Não tem conta? Criar conta'));
    await tester.pumpAndSettle();
    await capture(tester, 'criar-conta');
  });

  screenshots('anunciar um salão', (tester, app) async {
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
