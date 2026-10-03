import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_relation.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

import '../support/app_harness.dart';
import '../support/party_harness.dart';

/// Fluxos de favoritos e do Party Maker, a partir dos anúncios da vitrine.
void main() {
  const salao = 'Salão Glamour 8'; // R$ 1.700,00, até 240 pessoas
  const atracao = 'Atração Festiva 8'; // R$ 270,00 por hora
  const decoracao = 'Decoração Encanto 8'; // sob consulta
  const taxa = 'Taxa de limpeza'; // R$ 150,00, obrigatória com o salão
  const festa = '15 anos da Maria';

  /// Abre a aba Explorar filtrada em Atrações e começa a pôr [atracao] na
  /// festa [title]: fica na tela de configuração do item.
  ///
  /// [alreadyInParty] diz que o anúncio já está em alguma festa: o "+" dele
  /// avisa isso no próprio rótulo.
  Future<void> startAddingAttractionTo(
    WidgetTester tester,
    String title, {
    bool alreadyInParty = false,
  }) async {
    await openTab(tester, 'Explorar');
    await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Atrações'));
    await tapAndSettle(
      tester,
      find.byTooltip(
        alreadyInParty
            ? '$atracao já está em uma festa. Adicionar a outra'
            : 'Adicionar $atracao a uma festa',
      ),
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

  group('do anúncio até a festa', () {
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

    appTest('escolhida a festa, o anúncio abre para ser configurado, e nada '
        'entra antes de confirmar', (tester, app) async {
      await startAddingToNewParty(tester, salao, title: festa);

      expect(find.widgetWithText(AppBar, 'Adicionar à festa'), findsOneWidget);
      expect(find.text(salao), findsOneWidget);
      expect(find.text('Comporta até 240 pessoas'), findsOneWidget);
      // Só o que um salão pede: os dados do evento, a duração e os serviços
      // da própria casa.
      expect(find.text('Dados do evento'), findsOneWidget);
      expect(find.text('Sobre este item'), findsOneWidget);
      expect(find.text('Serviços de $salao'), findsOneWidget);
      expect(find.text('Buffet do salão'), findsOneWidget);
      expect(find.text('Estimativa deste item'), findsOneWidget);
      // Um salão é contratado uma vez só: não há campo de quantidade.
      expect(find.widgetWithText(TextFormField, 'Quantidade'), findsNothing);

      await tapAndSettle(tester, find.byType(BackButton));
      expect(app.state.parties.parties, isEmpty);
    });

    appTest('o salão não entra sem a data, os convidados e a duração', (
      tester,
      app,
    ) async {
      await startAddingToNewParty(tester, salao, title: festa);

      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      expect(find.text('Informe a data da festa.'), findsOneWidget);
      expect(find.text('Informe o número de convidados.'), findsOneWidget);
      expect(find.text('Campo obrigatório.'), findsOneWidget);
      expect(app.state.parties.parties, isEmpty);
    });

    appTest('os convidados não passam do que o salão comporta', (
      tester,
      app,
    ) async {
      await startAddingToNewParty(tester, salao, title: festa);
      await fillVenue(tester, guests: '500');

      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      expect(find.text('O espaço comporta até 240 pessoas.'), findsOneWidget);
      expect(app.state.parties.parties, isEmpty);
    });

    appTest('a estimativa acompanha o que a pessoa preenche, e nunca '
        'inventa um valor', (tester, app) async {
      await startAddingToNewParty(tester, salao, title: festa);

      // O salão (R$ 1.700) e a taxa obrigatória (R$ 150).
      expect(find.text(formatBrl(185000)), findsOneWidget);

      // O buffet é por pessoa: sem os convidados, não há como estimar.
      await scrollToAndTap(tester, find.text('Buffet do salão'));
      expect(
        find.text('${formatBrl(185000)} + 1 sob consulta'),
        findsOneWidget,
      );

      // Com 80 convidados: R$ 45 x 80 = R$ 3.600.
      await enterField(tester, 'Número de convidados', '80');
      expect(find.text(formatBrl(185000 + 360000)), findsOneWidget);
    });

    appTest('um serviço obrigatório já vem marcado e não pode ser '
        'desmarcado', (tester, app) async {
      await startAddingToNewParty(tester, salao, title: festa);

      final cleaning = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, taxa),
      );
      final buffet = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Buffet do salão'),
      );

      expect(cleaning.value, isTrue);
      expect(cleaning.onChanged, isNull);
      expect(buffet.value, isFalse);
      expect(buffet.onChanged, isNotNull);
    });

    appTest('cria a festa com o salão configurado e confirma com uma '
        'mensagem', (tester, app) async {
      await addVenueToNewParty(tester, salao, title: festa);

      expect(find.text('$salao adicionado a $festa.'), findsOneWidget);
      expect(
        find.byTooltip('$salao já está em uma festa. Adicionar a outra'),
        findsOneWidget,
      );

      final party = app.state.parties.parties.single;
      expect(party.status, PartyStatus.planning);
      expect(party.guestCount!.value, 80);
      expect(party.eventDate, isNotNull);
      // O salão entrou com a taxa obrigatória dele.
      expect(party.budget.items.map((item) => item.nameSnapshot), [
        salao,
        taxa,
      ]);
      expect(party.budget.items.last.relation.kind, ItemRelationKind.required);
      expect(party.estimate.total, Money.fromCents(185000));
    });

    appTest('o aviso de confirmação leva até a festa', (tester, app) async {
      await addVenueToNewParty(tester, salao, title: festa);

      await tapAndSettle(tester, find.text('Ver festa'));

      expect(find.widgetWithText(AppBar, festa), findsOneWidget);
      expect(find.text(salao), findsOneWidget);
    });

    appTest('um item cobrado por hora pede só a duração', (tester, app) async {
      await seedParty(tester, app, title: festa, withAttraction: false);
      await startAddingAttractionTo(tester, festa);

      // Nada do evento é pedido de novo.
      expect(find.text('Dados do evento'), findsNothing);
      expect(find.text('Serviços de $atracao'), findsNothing);
      // Sem a duração, não há como estimar.
      expect(find.text(onRequestLabel), findsOneWidget);

      await enterField(tester, 'Duração (horas)', '3');
      expect(find.text(formatBrl(81000)), findsOneWidget);

      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      expect(find.text('$atracao adicionado a $festa.'), findsOneWidget);
      expect(app.state.parties.parties.single.budget.items, hasLength(3));
    });

    appTest('um anúncio que já está na festa abre para ser alterado, em vez '
        'de entrar duas vezes', (tester, app) async {
      await seedParty(tester, app, title: festa);
      await startAddingAttractionTo(tester, festa, alreadyInParty: true);

      expect(find.widgetWithText(AppBar, 'Alterar item'), findsOneWidget);
      expect(find.textContaining('já está em $festa'), findsOneWidget);
      // Abre com o que a pessoa tinha informado.
      expect(find.widgetWithText(TextFormField, '4'), findsOneWidget);

      await enterField(tester, 'Duração (horas)', '6');
      await tapAndSettle(tester, filledButton('Salvar alterações'));

      expect(find.text('$atracao atualizado em $festa.'), findsOneWidget);
      final items = app.state.parties.parties.single.budget.items;
      expect(items, hasLength(3));
      expect(items.last.configuration.durationHours, 6);
    });

    appTest('uma festa aceita só um salão, e o formulário explica o motivo', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);

      await tapAndSettle(
        tester,
        find.byTooltip('Adicionar Salão Glamour 7 a uma festa'),
      );
      await tapAndSettle(tester, find.widgetWithText(ListTile, festa));
      await enterField(tester, 'Duração (horas)', '4');
      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      expect(
        find.text(
          'Esta festa já tem um salão. Remova o atual para escolher outro.',
        ),
        findsOneWidget,
      );
      // O formulário continua aberto, com o que foi preenchido.
      expect(find.widgetWithText(AppBar, 'Adicionar à festa'), findsOneWidget);
      expect(app.state.parties.parties.single.budget.items, hasLength(3));
    });
  });

  group('a festa', () {
    appTest('sem festas, a aba convida a criar a primeira', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Minhas festas');

      expect(find.text('Você ainda não tem festas'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Criar festa'));
      expect(find.widgetWithText(AppBar, 'Nova festa'), findsOneWidget);

      // Sem nome, não cria.
      await tapAndSettle(tester, filledButton('Criar festa'));
      expect(find.text('Dê um nome para a festa.'), findsOneWidget);

      await enterField(tester, 'Nome da festa', festa);
      await tapAndSettle(tester, filledButton('Criar festa'));

      // A festa nasce vazia e já aberta, dizendo por onde começar.
      expect(find.widgetWithText(AppBar, festa), findsOneWidget);
      expect(find.text('Sua festa ainda não tem itens'), findsOneWidget);
      expect(find.text('Data a definir'), findsOneWidget);
      expect(find.text('Convidados a definir'), findsOneWidget);

      await revealAndTap(tester, filledButton('Explorar anúncios'));
      expect(find.widgetWithText(FilterChip, 'Atrações'), findsOneWidget);
    });

    appTest('mostra o evento, os itens por categoria e a estimativa', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);

      await openTab(tester, 'Minhas festas');

      expect(find.widgetWithText(AppBar, festa), findsOneWidget);
      expect(find.text('Em planejamento'), findsOneWidget);
      expect(find.text('80 convidados'), findsOneWidget);
      // R$ 1.700 + R$ 150 + R$ 270 x 4 h. O rodapé fica sempre à vista.
      expect(find.text('Estimativa do evento'), findsOneWidget);
      expect(find.text(formatBrl(293000)), findsOneWidget);
      // Ninguém respondeu ainda: não há orçamento a mostrar.
      expect(find.textContaining('Orçamento recebido'), findsNothing);

      // Cada item no grupo da sua categoria, do lugar para o que acontece
      // nele.
      await reveal(tester, find.text('Espaço'));
      await reveal(tester, find.text(salao));
      expect(find.text('4 horas'), findsWidgets);
      await reveal(tester, find.text('Atrações'));
      await reveal(tester, find.text(atracao));
      await reveal(tester, find.text('Produtos e outros'));
      await reveal(tester, find.text('Obrigatório com $salao'));
    });

    appTest('alterar um item recalcula a estimativa', (tester, app) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      await revealAndTap(tester, find.byTooltip('Alterar $atracao'));
      await enterField(tester, 'Duração (horas)', '2');
      await tapAndSettle(tester, filledButton('Salvar alterações'));

      expect(find.text('$atracao atualizado.'), findsOneWidget);
      expect(find.text('2 horas'), findsOneWidget);
      // R$ 1.700 + R$ 150 + R$ 270 x 2 h
      expect(find.text(formatBrl(239000)), findsOneWidget);
    });

    appTest('um serviço obrigatório não pode ser removido sozinho', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      final blocked = find.byTooltip('$taxa é obrigatório com $salao');
      await reveal(tester, blocked);
      final remove = tester.widget<IconButton>(
        find.ancestor(of: blocked, matching: find.byType(IconButton)),
      );

      // Desabilitado, dizendo por quê, em vez de responder com um erro.
      expect(remove.onPressed, isNull);
    });

    appTest('remover o salão avisa o que sai junto, e a festa continua '
        'existindo', (tester, app) async {
      await seedParty(tester, app, title: festa, withAttraction: false);
      await openTab(tester, 'Minhas festas');

      await revealAndTap(tester, find.byTooltip('Remover $salao'));
      expect(find.text('Remover $salao?'), findsOneWidget);
      expect(
        find.textContaining('Também sai da festa: $taxa.'),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Cancelar'));
      expect(app.state.parties.parties.single.budget.items, hasLength(2));

      await revealAndTap(tester, find.byTooltip('Remover $salao'));
      await tapAndSettle(tester, find.text('Remover'));

      expect(find.text('$salao removido, com $taxa.'), findsOneWidget);
      expect(find.text('Sua festa ainda não tem itens'), findsOneWidget);
      // A festa não é apagada por ficar vazia.
      expect(app.state.parties.parties.single.budget.isEmpty, isTrue);
    });

    appTest('os parceiros que o salão recomenda aparecem na festa e entram '
        'ligados a ele', (tester, app) async {
      await seedParty(tester, app, title: festa, withAttraction: false);
      await openTab(tester, 'Minhas festas');

      await reveal(tester, find.text('Recomendados por $salao'));
      expect(find.text(atracao), findsOneWidget);

      await revealAndTap(
        tester,
        find.byTooltip('Adicionar $decoracao à festa'),
      );
      // A decoração pede o tema, e nada do evento.
      expect(find.text('Dados do evento'), findsNothing);
      await enterField(tester, 'Tema', 'Safari');
      await tapAndSettle(tester, filledButton('Adicionar à festa'));

      // Quem já entrou sai das sugestões.
      expect(find.byTooltip('Adicionar $decoracao à festa'), findsNothing);
      expect(find.byTooltip('Adicionar $atracao à festa'), findsOneWidget);
      // O que é sob consulta fica fora da soma, e a tela diz isso.
      expect(
        find.text('${formatBrl(185000)} + 1 sob consulta'),
        findsOneWidget,
      );

      await reveal(tester, find.text('Recomendado por $salao'));
      expect(find.text('Tema: Safari'), findsOneWidget);
      final decoration = app.state.parties.parties.single.budget.items.last;
      expect(decoration.relation.kind, ItemRelationKind.recommended);
    });

    appTest('os dados do evento podem ser alterados, e a estimativa por '
        'pessoa acompanha', (tester, app) async {
      await seedParty(tester, app, title: festa, withBuffet: true);
      await openTab(tester, 'Minhas festas');
      // R$ 1.700 + R$ 150 + R$ 45 x 80 + R$ 270 x 4 h
      expect(find.text(formatBrl(653000)), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Editar dados do evento'));
      await enterField(tester, 'Nome da festa', 'Festa da Maria');
      await enterField(tester, 'Número de convidados (opcional)', '100');
      await scrollToAndTap(tester, filledButton('Salvar'));

      expect(find.widgetWithText(AppBar, 'Festa da Maria'), findsOneWidget);
      expect(find.text('100 convidados'), findsOneWidget);
      // R$ 45 x 100
      expect(find.text(formatBrl(743000)), findsOneWidget);
    });

    appTest('com mais de uma festa, a lista mostra cada uma e abre a '
        'escolhida', (tester, app) async {
      await seedParty(tester, app, title: festa);
      await seedParty(
        tester,
        app,
        title: 'Casamento',
        venueId: 'demo-venue-7',
        withAttraction: false,
      );
      await openTab(tester, 'Perfil');

      await scrollToAndTap(tester, find.text('Minhas Festas'));

      expect(find.widgetWithText(AppBar, 'Minhas Festas'), findsOneWidget);
      expect(find.text(festa), findsOneWidget);
      expect(find.text('Casamento'), findsOneWidget);
      expect(
        find.text('3 itens · Estimativa: ${formatBrl(293000)}'),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Casamento'));
      expect(find.widgetWithText(AppBar, 'Casamento'), findsOneWidget);
      expect(find.text('Salão Glamour 7'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Voltar para as festas'));
      expect(find.widgetWithText(AppBar, 'Minhas Festas'), findsOneWidget);
    });

    appTest('apagar uma festa em planejamento pede confirmação', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      await tapAndSettle(tester, find.byTooltip('Mais opções da festa'));
      await tapAndSettle(tester, find.text('Apagar festa'));
      expect(find.text('Apagar esta festa?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Apagar'));

      expect(find.text('$festa apagada.'), findsOneWidget);
      expect(find.text('Você ainda não tem festas'), findsOneWidget);
      expect(app.state.parties.parties, isEmpty);
    });
  });

  group('orçamento', () {
    appTest('a festa diz o que falta para pedir, e o botão espera', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Minhas festas');
      await tapAndSettle(tester, filledButton('Criar festa'));
      await enterField(tester, 'Nome da festa', festa);
      await tapAndSettle(tester, filledButton('Criar festa'));
      await startAddingAttractionTo(tester, festa);
      await enterField(tester, 'Duração (horas)', '4');
      await tapAndSettle(tester, filledButton('Adicionar à festa'));
      await tapAndSettle(tester, find.text('Ver festa'));

      expect(find.text('Falta para pedir o orçamento'), findsOneWidget);
      expect(
        find.text('• Informe a data da festa antes de solicitar o orçamento.'),
        findsOneWidget,
      );
      expect(
        find.text('• Informe o número de convidados da festa.'),
        findsOneWidget,
      );
      // O botão não aceita o toque para depois responder com um erro.
      expect(
        tester
            .widget<FilledButton>(filledButton('Solicitar orçamento'))
            .onPressed,
        isNull,
      );

      await revealAndTap(tester, find.text('Informar dados do evento'));
      await fillEvent(tester, optional: true);
      await scrollToAndTap(tester, filledButton('Salvar'));

      expect(find.text('Falta para pedir o orçamento'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(filledButton('Solicitar orçamento'))
            .onPressed,
        isNotNull,
      );
    });

    appTest('solicitar explica o que é enviado e congela a festa', (
      tester,
      app,
    ) async {
      await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      await tapAndSettle(tester, filledButton('Solicitar orçamento'));
      expect(find.text('Solicitar orçamento?'), findsOneWidget);
      expect(
        find.textContaining('Seu nome e o nome da festa não são enviados'),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('Solicitar'));

      expect(find.text('Orçamento solicitado'), findsOneWidget);
      expect(filledButton('Solicitar orçamento'), findsNothing);
      expect(filledButton('Editar festa'), findsOneWidget);
      // Cada item foi para o fornecedor dele.
      final party = app.state.parties.parties.single;
      expect(party.status, PartyStatus.locked);
      expect(
        party.budget.items.map((item) => item.quote.status),
        everyElement(QuoteStatus.pending),
      );

      // Congelada: nada de alterar ou remover até voltar a editar.
      final editVenue = find.byTooltip('Alterar $salao');
      await reveal(tester, editVenue);
      expect(find.text('Aguardando o fornecedor'), findsWidgets);
      final edit = tester.widget<IconButton>(
        find.ancestor(of: editVenue, matching: find.byType(IconButton)),
      );
      expect(edit.onPressed, isNull);
    });

    appTest('festa com o orçamento solicitado não aparece na escolha de '
        'onde adicionar', (tester, app) async {
      final party = await seedParty(tester, app, title: festa);
      await app.state.parties.requestQuote(party.id);
      await tester.pumpAndSettle();

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

    appTest('no modo demonstração, a própria pessoa responde como '
        'fornecedor', (tester, app) async {
      final party = await seedParty(
        tester,
        app,
        title: festa,
        withAttraction: false,
      );
      await app.state.parties.requestQuote(party.id);
      await openTab(tester, 'Minhas festas');

      await tapAndSettle(tester, find.text('Responder como fornecedor (demo)'));

      expect(
        find.widgetWithText(AppBar, 'Pedidos de orçamento'),
        findsOneWidget,
      );
      // O fornecedor vê o evento e o item, e nada de quem pediu.
      expect(find.textContaining(festa), findsNothing);
      expect(find.textContaining('80 convidados'), findsOneWidget);
      expect(find.text('Aguardando a sua resposta'), findsNWidgets(2));
      expect(find.text('Obrigatório com $salao'), findsOneWidget);

      await tapAndSettle(tester, find.text('Informar valor').first);
      await tapAndSettle(tester, filledButton('Enviar valor'));
      expect(
        find.text('Informe o valor, por exemplo 1500 ou 1.500,00.'),
        findsOneWidget,
      );
      await enterField(tester, 'Valor do orçamento', '1.800');
      await enterField(
        tester,
        'Mensagem para o cliente (opcional)',
        'Inclui a montagem',
      );
      await tapAndSettle(tester, filledButton('Enviar valor'));

      expect(
        find.text('Valor enviado. O cliente vê o orçamento na festa dele.'),
        findsOneWidget,
      );
      expect(find.text('Você informou ${formatBrl(180000)}'), findsOneWidget);
      expect(find.text('"Inclui a montagem"'), findsOneWidget);

      await tapAndSettle(tester, find.byType(BackButton));

      // De volta à festa: a resposta chegou, separada da estimativa.
      expect(find.text('Orçamento recebido (1 de 2)'), findsOneWidget);
      expect(find.text('Estimativa do evento'), findsOneWidget);
      expect(find.text(formatBrl(185000)), findsOneWidget);
      await reveal(tester, find.text('Orçamento: ${formatBrl(180000)}'));
      expect(find.text('"Inclui a montagem"'), findsOneWidget);
    });

    appTest('recebido o orçamento, a festa mostra o total e pode ser '
        'aceita', (tester, app) async {
      final party = await seedParty(tester, app, title: festa);
      await app.state.parties.requestQuote(party.id);
      await answerAll(app, cents: 100000);
      await openTab(tester, 'Minhas festas');

      // A festa na tela ainda é a de antes das respostas.
      expect(find.text('Orçamento solicitado'), findsOneWidget);
      await tapAndSettle(tester, find.byTooltip('Atualizar a festa'));

      expect(find.text('Orçamento recebido'), findsNWidgets(2));
      // Três itens a R$ 1.000 cada; a estimativa continua ao lado.
      expect(find.text(formatBrl(300000)), findsOneWidget);
      expect(find.text(formatBrl(293000)), findsOneWidget);

      await tapAndSettle(tester, filledButton('Aceitar orçamento'));
      expect(find.text('Aceitar o orçamento?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Aceitar'));

      expect(find.text('Orçamento aceito'), findsOneWidget);
      expect(app.state.parties.parties.single.status, PartyStatus.confirmed);
    });

    appTest('edição solicitada: a pessoa vê o recado, ajusta o item e '
        'reenvia', (tester, app) async {
      final party = await seedParty(tester, app, title: festa);
      await app.state.parties.requestQuote(party.id);
      final attraction = party.budget.items.last;
      await app.dependencies.quoteInbox.respond(
        attraction.id.value,
        const VendorResponse.requestChanges('Atendo no máximo 3 horas.'),
      );
      await app.state.parties.load();
      await openTab(tester, 'Minhas festas');

      expect(find.text('Edição solicitada'), findsOneWidget);
      await reveal(tester, find.text('O fornecedor pediu uma alteração'));
      expect(find.text('"Atendo no máximo 3 horas."'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Editar festa'));
      expect(find.text('Festa liberada para edição.'), findsOneWidget);
      await waitSnackBarLeave(tester);

      await revealAndTap(tester, find.byTooltip('Alterar $atracao'));
      await enterField(tester, 'Duração (horas)', '3');
      await tapAndSettle(tester, filledButton('Salvar alterações'));
      await waitSnackBarLeave(tester);

      await tapAndSettle(tester, filledButton('Solicitar orçamento'));
      await tapAndSettle(tester, find.text('Solicitar'));

      // É a segunda vez que a festa é enviada.
      await reveal(
        tester,
        find.text('Orçamento solicitado (2ª rodada)'),
        upwards: true,
      );
      final saved = app.state.parties.parties.single;
      expect(saved.quoteRound, 2);
      expect(saved.budget.items.last.quote.status, QuoteStatus.pending);
    });

    appTest('o histórico guarda cada pedido e cada resposta', (
      tester,
      app,
    ) async {
      final party = await seedParty(tester, app, title: festa);
      await openTab(tester, 'Minhas festas');

      await choosePartyOption(tester, 'Histórico da festa');
      expect(find.text('Nada por aqui ainda'), findsOneWidget);
      await tapAndSettle(tester, find.byType(BackButton));

      await app.state.parties.requestQuote(party.id);
      await answerAll(app, cents: 100000);
      await app.state.parties.load();
      await tester.pumpAndSettle();
      await choosePartyOption(tester, 'Histórico da festa');

      expect(find.text('Você solicitou o orçamento'), findsOneWidget);
      expect(find.text('Estimativa: ${formatBrl(293000)}'), findsOneWidget);
      expect(
        find.text('$salao: o fornecedor informou ${formatBrl(100000)}'),
        findsOneWidget,
      );
    });

    appTest('cancelar uma festa com o orçamento solicitado pede '
        'confirmação, e só depois ela pode ser apagada', (tester, app) async {
      final party = await seedParty(tester, app, title: festa);
      await app.state.parties.requestQuote(party.id);
      await openTab(tester, 'Minhas festas');

      await tapAndSettle(tester, find.byTooltip('Mais opções da festa'));
      // Com o pedido nas mãos dos fornecedores, não há "apagar".
      expect(find.text('Apagar festa'), findsNothing);
      await tapAndSettle(tester, find.text('Cancelar festa'));
      expect(find.text('Cancelar esta festa?'), findsOneWidget);
      await tapAndSettle(tester, find.text('Cancelar a festa'));

      expect(find.text('Cancelado'), findsOneWidget);
      expect(app.state.parties.parties.single.status, PartyStatus.cancelled);
      await waitSnackBarLeave(tester);

      await tapAndSettle(tester, find.byTooltip('Mais opções da festa'));
      await tapAndSettle(tester, find.text('Apagar festa'));
      await tapAndSettle(tester, find.text('Apagar'));

      expect(app.state.parties.parties, isEmpty);
    });

    appTest('o perfil conta festas em planejamento e orçamentos', (
      tester,
      app,
    ) async {
      final party = await seedParty(tester, app, title: festa);
      await app.state.parties.requestQuote(party.id);
      await seedParty(
        tester,
        app,
        title: 'Casamento',
        venueId: 'demo-venue-7',
        withAttraction: false,
      );

      await openTab(tester, 'Perfil');

      expect(find.bySemanticsLabel('1 Festas em planejamento'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Orçamentos solicitados'), findsOneWidget);
    });
  });
}
