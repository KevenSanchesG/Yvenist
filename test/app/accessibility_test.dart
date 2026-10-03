import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/client/shared/listing_card.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../support/app_harness.dart';
import '../support/party_harness.dart';
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

  const salao = 'Salão Glamour 8';
  const festa = 'Casamento';

  /// Passa por cada estado da festa, do planejamento ao orçamento aceito,
  /// chamando [check] em cada tela. É o mesmo caminho para as diretrizes, as
  /// letras grandes e o tema escuro.
  Future<void> walkThroughParty(
    WidgetTester tester,
    TestApp app,
    Future<void> Function() check,
  ) async {
    final party = await seedParty(tester, app, title: festa);
    await openTab(tester, 'Minhas festas');
    await check();

    // A lista inteira: os itens, os parceiros recomendados e o serviço
    // obrigatório, que não pode sair sozinho.
    await reveal(tester, find.text('Recomendados por $salao'));
    await check();
    await reveal(tester, find.text('Obrigatório com $salao'));
    await check();

    await tapAndSettle(tester, find.byTooltip('Mais opções da festa'));
    await check();
    await tapAndSettle(tester, find.text('Histórico da festa'));
    await check();
    await tapAndSettle(tester, find.byType(BackButton));

    await choosePartyOption(tester, 'Editar dados do evento');
    await check();
    await tapAndSettle(tester, find.byType(BackButton));

    await tapAndSettle(tester, filledButton('Solicitar orçamento'));
    await check();
    await tapAndSettle(tester, find.text('Solicitar'));
    await waitSnackBarLeave(tester);
    await check();

    // Um fornecedor devolve o item dele; os outros informam o valor.
    final inbox = app.dependencies.quoteInbox;
    await inbox.respond(
      party.budget.items.last.id.value,
      const VendorResponse.requestChanges('Atendo no máximo 3 horas.'),
    );
    await tapAndSettle(tester, find.byTooltip('Atualizar a festa'));
    await check();
    await reveal(tester, find.text('O fornecedor pediu uma alteração'));
    await check();

    await answerAll(app, cents: 100000);
    await tapAndSettle(tester, find.byTooltip('Atualizar a festa'));
    await check();

    await choosePartyOption(tester, 'Histórico da festa');
    await check();
    await tapAndSettle(tester, find.byType(BackButton));

    await tapAndSettle(tester, filledButton('Aceitar orçamento'));
    await check();
    await tapAndSettle(tester, find.text('Aceitar'));
    await waitSnackBarLeave(tester);
    await check();

    await tapAndSettle(tester, find.byTooltip('Voltar para as festas'));
    await check();
  }

  /// A configuração de um salão, do formulário vazio ao formulário com os
  /// erros na tela e com um serviço da casa escolhido.
  Future<void> walkThroughVenueConfiguration(
    WidgetTester tester,
    Future<void> Function() check,
  ) async {
    await scrollToAndTap(
      tester,
      find.byTooltip('Adicionar $salao a uma festa'),
    );
    await check();
    await tapAndSettle(tester, find.text('Criar nova festa'));
    await check();
    await tester.enterText(find.byType(TextField), festa);
    await tester.pump();
    await tapAndSettle(tester, filledButton('Criar festa'));
    await check();

    await scrollToAndTap(tester, find.text('Animação da casa'));
    await check();
    await tapAndSettle(tester, filledButton('Adicionar à festa'));
    await check();
  }

  /// A caixa de pedidos do fornecedor, com os diálogos de resposta.
  Future<void> walkThroughQuoteInbox(
    WidgetTester tester,
    TestApp app,
    Future<void> Function() check,
  ) async {
    final party = await seedParty(tester, app, title: festa);
    await app.state.parties.requestQuote(party.id);
    await openTab(tester, 'Minhas festas');
    await tapAndSettle(tester, find.text('Responder como fornecedor (demo)'));
    await check();

    await scrollToAndTap(tester, find.text('Informar valor').first);
    await check();
    await scrollToAndTap(tester, filledButton('Enviar valor'));
    await check();
    await scrollToAndTap(tester, find.text('Cancelar'));

    await scrollToAndTap(tester, find.text('Pedir alteração').first);
    await check();
    await enterField(
      tester,
      'O que o cliente precisa mudar',
      'Atendo no máximo 3 horas.',
    );
    await scrollToAndTap(tester, filledButton('Pedir alteração'));
    await waitSnackBarLeave(tester);
    await check();
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

    appTest('escolha da festa, com festas para escolher', (tester, app) async {
      await seedParty(tester, app, title: festa);
      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 7 a uma festa'),
      );

      await expectAccessible(tester);
    });

    appTest('configuração de um item, com os erros na tela', (
      tester,
      app,
    ) async {
      await walkThroughVenueConfiguration(
        tester,
        () => expectAccessible(tester),
      );
    });

    appTest('festas: sem nenhuma e criando a primeira', (tester, app) async {
      await openTab(tester, 'Minhas festas');
      await expectAccessible(tester);

      await tapAndSettle(tester, filledButton('Criar festa'));
      await expectAccessible(tester);
      await tapAndSettle(tester, filledButton('Criar festa'));
      await expectAccessible(tester);

      await enterField(tester, 'Nome da festa', festa);
      await tapAndSettle(tester, filledButton('Criar festa'));
      await expectAccessible(tester);
    });

    appTest('a festa, do planejamento ao orçamento aceito', (
      tester,
      app,
    ) async {
      await walkThroughParty(tester, app, () => expectAccessible(tester));
    });

    appTest('pedidos de orçamento do fornecedor, com os diálogos', (
      tester,
      app,
    ) async {
      await walkThroughQuoteInbox(tester, app, () => expectAccessible(tester));
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

    appTest('aparência', (tester, app) async {
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Aparência'));

      await expectAccessible(tester);
    });

    appTest('perfil de quem não entrou, com o atalho de aparência', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');

      await expectAccessible(tester);
    }, signedIn: false);

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

      expect(find.bySemanticsLabel('Etapa 1 de 7'), findsOneWidget);
    });

    appTest('os títulos das partes da festa são anunciados como títulos', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      // Em que pé a festa está e cada grupo de itens: é por eles que quem usa
      // um leitor de tela percorre a festa.
      expect(
        tester.getSemantics(find.text('Em planejamento')),
        isSemantics(isHeader: true),
      );
      await reveal(tester, find.text('Espaço'));
      expect(
        tester.getSemantics(find.text('Espaço')),
        isSemantics(isHeader: true),
      );
    });

    appTest('cada botão de um item diz qual item ele afeta', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');
      await reveal(tester, find.byTooltip('Alterar $salao'));

      expect(find.byTooltip('Alterar $salao'), findsOneWidget);
      expect(find.byTooltip('Remover $salao'), findsOneWidget);
      expect(
        find.byTooltip('Adicionar Decoração Encanto 8 à festa'),
        findsOneWidget,
      );
    });

    appTest('a estimativa de um item é anunciada quando muda', (
      tester,
      app,
    ) async {
      await startAddingToNewParty(tester, salao, title: festa);

      expect(
        tester.getSemantics(find.text('Estimativa deste item')),
        isSemantics(isLiveRegion: true),
      );
    });

    appTest('a data e o horário do evento são botões que abrem o seletor', (
      tester,
      app,
    ) async {
      // Regressão: os dois eram campos de texto só de leitura. O dedo abria o
      // calendário, mas o Flutter não publica a ação de um campo só de
      // leitura: para o leitor de tela eles eram um texto, sem nada para
      // acionar. Visto no Android, onde os dois apareciam como não tocáveis.
      await startAddingToNewParty(tester, salao, title: festa);

      for (final label in ['Data', 'Horário de início']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isButton: true, hasTapAction: true),
          reason: label,
        );
      }

      // Acionar pelo leitor de tela faz o mesmo que o toque do dedo.
      tester.semantics.tap(find.semantics.byLabel('Data'));
      await tester.pumpAndSettle();
      expect(find.text('Data da festa'), findsOneWidget);
      await tapAndSettle(tester, find.text('Cancelar'));

      tester.semantics.tap(find.semantics.byLabel('Horário de início'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);
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

      expect(find.text('Você ainda não tem festas'), findsOneWidget);
    });

    appTest('o rodapé da festa não fica por baixo do botão central', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      final action = tester.getRect(filledButton('Solicitar orçamento'));
      final button = tester.getRect(tabButton('Minhas festas'));

      // O botão central sobe acima da barra: o rodapé guarda essa folga.
      expect(action.bottom, lessThanOrEqualTo(button.top));
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

    /// Nada a conferir além do que o próprio teste já confere: um estouro de
    /// layout, ou um controle que não dá para alcançar, falha sozinho.
    Future<void> noCheck() async {}

    appTest('início e explorar', (tester, app) async {
      await openTab(tester, 'Explorar');
      await openTab(tester, 'Início');

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
    }, textScale: scale);

    appTest('configuração de um item, com os erros na tela', (
      tester,
      app,
    ) async {
      await walkThroughVenueConfiguration(tester, noCheck);

      expect(find.text('Informe a data da festa.'), findsOneWidget);
    }, textScale: scale);

    appTest('festas: sem nenhuma, criando a primeira e a festa vazia', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Minhas festas');
      await scrollToAndTap(tester, filledButton('Criar festa'));
      await enterField(tester, 'Nome da festa', festa);
      await scrollToAndTap(tester, filledButton('Criar festa'));

      expect(find.widgetWithText(AppBar, festa), findsOneWidget);
      await reveal(tester, filledButton('Explorar anúncios'));
    }, textScale: scale);

    appTest('a festa, do planejamento ao orçamento aceito', (
      tester,
      app,
    ) async {
      await walkThroughParty(tester, app, noCheck);

      expect(find.text('Orçamento aceito'), findsOneWidget);
    }, textScale: scale);

    appTest('pedidos de orçamento do fornecedor, com os diálogos', (
      tester,
      app,
    ) async {
      await walkThroughQuoteInbox(tester, app, noCheck);

      expect(find.text('Você pediu uma alteração'), findsOneWidget);
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
      await scrollToAndTap(tester, find.text('Aparência'));
      await scrollToAndTap(tester, find.text('Escuro'));
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

      // Com letras grandes uma etapa pode não caber na tela, e o que está
      // mais abaixo só existe depois de rolar a lista dela.
      Future<void> revealInStep(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          120,
          scrollable: find
              .descendant(
                of: find.byType(Form),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }

      Future<void> fill(String label, String text) async {
        await revealInStep(find.widgetWithText(TextFormField, label));
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

      // Os serviços do próprio espaço, com o diálogo que cadastra um.
      await revealInStep(find.text('Adicionar serviço'));
      await tapAndSettle(tester, find.text('Adicionar serviço'));
      await enterField(tester, 'Nome do serviço', 'Taxa de limpeza');
      await scrollToAndTap(
        tester,
        find.byType(DropdownButtonFormField<String>),
      );
      await tapAndSettle(tester, find.text('Outros').last);
      await enterField(tester, 'Preço do serviço', '150');
      await scrollToAndTap(tester, find.text('Obrigatório'));
      await scrollToAndTap(tester, filledButton('Adicionar'));
      expect(find.byTooltip('Remover Taxa de limpeza'), findsOneWidget);
      await next();

      expect(find.text('Confira antes de enviar'), findsOneWidget);
      expect(filledButton('Enviar anúncio'), findsOneWidget);
    }, textScale: scale);
  });

  group('tema escuro', () {
    // O tema escuro troca sombra por borda e muda as cores de cada peça. As
    // mesmas telas passam pelas mesmas conferências: um estouro de layout faz
    // o teste falhar sozinho.
    appTest('início e explorar', (tester, app) async {
      // Regressão: no escuro o card de anúncio ganhou uma borda que tirava um
      // pixel do conteúdo, e a coluna do card estourava a altura fixa da
      // lista horizontal.
      await useDarkTheme(tester, app);
      await expectAccessible(tester);

      await openTab(tester, 'Explorar');
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));
      await expectAccessible(tester);
    });

    appTest('configuração de um item, com os erros na tela', (
      tester,
      app,
    ) async {
      await useDarkTheme(tester, app);

      await walkThroughVenueConfiguration(
        tester,
        () => expectAccessible(tester),
      );
    });

    appTest('a festa, do planejamento ao orçamento aceito', (
      tester,
      app,
    ) async {
      await useDarkTheme(tester, app);

      await walkThroughParty(tester, app, () => expectAccessible(tester));
    });

    appTest('pedidos de orçamento do fornecedor, com os diálogos', (
      tester,
      app,
    ) async {
      await useDarkTheme(tester, app);

      await walkThroughQuoteInbox(tester, app, () => expectAccessible(tester));
    });

    appTest('perfil, aparência, segurança e termos', (tester, app) async {
      await useDarkTheme(tester, app);
      await openTab(tester, 'Perfil');
      await expectAccessible(tester);

      await scrollToAndTap(tester, find.text('Aparência'));
      await expectAccessible(tester);
      await tapAndSettle(tester, find.byType(BackButton));

      await scrollToAndTap(tester, find.text('Segurança'));
      await expectAccessible(tester);
      await tapAndSettle(tester, find.byType(BackButton));

      await scrollToAndTap(tester, find.text('Termos e Política'));
      await tapAndSettle(tester, find.text('Termos de Uso'));
      await expectAccessible(tester);
    });

    appTest('entrar e criar conta, com erros na tela', (tester, app) async {
      await useDarkTheme(tester, app);
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
      await useDarkTheme(tester, app);
      await openHallForm(tester);
      await tapAndSettle(tester, filledButton('Avançar'));

      await expectAccessible(tester);
    });

    appTest('fila de análise', (tester, app) async {
      await useDarkTheme(tester, app);
      await openTab(tester, 'Perfil');
      await scrollToAndTap(tester, find.text('Fila de análise'));
      await expectAccessible(tester);

      await tapAndSettle(tester, find.text('Recusar'));
      await expectAccessible(tester);
      await tapAndSettle(tester, find.text('Cancelar'));

      await tapAndSettle(tester, find.text('Anúncios (2)'));
      await tapAndSettle(tester, find.text('Ver detalhes').first);
      await expectAccessible(tester);
    }, dependencies: () => adminDependencies(sampleReviewQueue()));

    appTest('início, explorar e a festa com letras grandes', (
      tester,
      app,
    ) async {
      await useDarkTheme(tester, app);
      await openTab(tester, 'Explorar');
      await openTab(tester, 'Início');

      await walkThroughParty(tester, app, () async {});

      expect(find.text('Orçamento aceito'), findsOneWidget);
    }, textScale: 2);
  });
}
