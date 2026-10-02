import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/utils/money_formatter.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';

import '../support/app_harness.dart';

/// Fluxo de quem quer anunciar: convite, cadastro do salão em etapas, análise
/// e modo fornecedor.
void main() {
  const validCpf = '529.982.247-25';

  Future<void> openHallForm(WidgetTester tester) async {
    await openTab(tester, 'Perfil');
    await tapAndSettle(tester, find.text('Tem um salão ou serviço?'));
    await tapAndSettle(tester, filledButton('Começar meu anúncio'));
    await tapAndSettle(tester, find.text('Salão de Festas'));
  }

  Future<void> next(WidgetTester tester) {
    return tapAndSettle(tester, filledButton('Avançar'));
  }

  Future<void> fillLegalStep(WidgetTester tester) async {
    await enterField(tester, 'CPF do responsável', validCpf);
    await enterField(tester, 'Nome completo', 'Maria Oliveira');
  }

  Future<void> fillHallStep(WidgetTester tester) async {
    await enterField(tester, 'Nome do salão', 'Espaço Crystal');
    await enterField(
      tester,
      'Descrição',
      'Salão amplo, climatizado, com cozinha equipada.',
    );
    await enterField(tester, 'Capacidade', '150');
    await enterField(tester, 'Cidade', 'Salvador');
    await scrollToAndTap(tester, find.byType(DropdownButtonFormField<String>));
    await tapAndSettle(tester, find.text('BA').last);
  }

  /// Preenche as cinco etapas e para na revisão.
  Future<void> fillUntilReview(WidgetTester tester) async {
    await fillLegalStep(tester);
    await next(tester);
    await fillHallStep(tester);
    await next(tester);
    await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Casamentos'));
    await next(tester);
    await tapAndSettle(tester, find.text('Wi-Fi'));
    await next(tester);
    await enterField(tester, 'Preço a partir de', '2.500');
    await tapAndSettle(tester, find.text('Moderada'));
    await next(tester);
  }

  Future<void> submitHall(WidgetTester tester) async {
    await openHallForm(tester);
    await fillUntilReview(tester);
    await tapAndSettle(tester, filledButton('Enviar anúncio'));
    await tapAndSettle(tester, filledButton('Entendido'));
  }

  group('convite', () {
    appTest('o perfil convida a anunciar e explica as vantagens', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Tem um salão ou serviço?'));

      expect(find.text('Transforme seu espaço em renda extra'), findsOneWidget);
      expect(find.text('Anunciar é gratuito'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Fechar'));
      expect(find.text('Conta Demonstração'), findsOneWidget);
    });

    appTest('só o salão pode ser anunciado; o resto aparece como "Em breve"', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      await tapAndSettle(tester, find.text('Tem um salão ou serviço?'));
      await tapAndSettle(tester, filledButton('Começar meu anúncio'));

      expect(find.text('Em breve'), findsNWidgets(3));

      // Tocar em uma categoria indisponível não leva a lugar nenhum.
      await tapAndSettle(tester, find.text('Buffet e Bar'));
      expect(
        find.widgetWithText(AppBar, 'O que você vai anunciar?'),
        findsOneWidget,
      );
    });

    appTest('o modo fornecedor só abre depois da aprovação', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');

      await tapAndSettle(tester, find.text('Modo Fornecedor'));

      expect(
        find.textContaining('depois que o seu anúncio é aprovado'),
        findsOneWidget,
      );
      expect(find.text('Fornecedor aprovado'), findsNothing);
    });
  });

  group('cadastro do salão', () {
    appTest('não avança sem os dados do responsável', (tester, app) async {
      await openHallForm(tester);
      expect(find.bySemanticsLabel('Etapa 1 de 6'), findsOneWidget);

      await next(tester);

      expect(find.text('Informe o CPF.'), findsOneWidget);
      expect(find.text('Informe o nome completo.'), findsOneWidget);
      expect(find.bySemanticsLabel('Etapa 1 de 6'), findsOneWidget);
    });

    appTest('confere os dígitos do CPF', (tester, app) async {
      await openHallForm(tester);
      await enterField(tester, 'CPF do responsável', '111.111.111-11');
      await enterField(tester, 'Nome completo', 'Maria Oliveira');

      await next(tester);

      expect(find.text('CPF inválido.'), findsOneWidget);
    });

    appTest('pessoa jurídica informa CNPJ e razão social', (tester, app) async {
      await openHallForm(tester);

      await tapAndSettle(tester, find.text('Pessoa Jurídica'));

      expect(find.widgetWithText(TextFormField, 'CNPJ'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Razão social'),
        findsOneWidget,
      );

      // Um CPF válido não serve como CNPJ.
      await enterField(tester, 'CNPJ', validCpf);
      await enterField(tester, 'Razão social', 'Crystal Eventos Ltda');
      await next(tester);
      expect(find.text('CNPJ inválido.'), findsOneWidget);

      await enterField(tester, 'CNPJ', '11.222.333/0001-81');
      await next(tester);
      expect(find.bySemanticsLabel('Etapa 2 de 6'), findsOneWidget);
    });

    appTest('valida os dados do salão', (tester, app) async {
      await openHallForm(tester);
      await fillLegalStep(tester);
      await next(tester);

      await enterField(tester, 'Descrição', 'Curta demais');
      await next(tester);

      expect(find.text('Informe o nome do salão.'), findsOneWidget);
      expect(
        find.text('Descreva o espaço com pelo menos 20 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('Informe a cidade.'), findsOneWidget);
      expect(find.text('Escolha a UF.'), findsOneWidget);
      expect(find.bySemanticsLabel('Etapa 2 de 6'), findsOneWidget);
    });

    appTest('exige ao menos um tipo de evento', (tester, app) async {
      await openHallForm(tester);
      await fillLegalStep(tester);
      await next(tester);
      await fillHallStep(tester);
      await next(tester);

      await next(tester);
      expect(
        find.text('Escolha pelo menos um tipo de evento.'),
        findsOneWidget,
      );

      // Escolher um apaga o aviso.
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Casamentos'));
      expect(find.text('Escolha pelo menos um tipo de evento.'), findsNothing);
    });

    appTest('valida o preço', (tester, app) async {
      await openHallForm(tester);
      await fillLegalStep(tester);
      await next(tester);
      await fillHallStep(tester);
      await next(tester);
      await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Casamentos'));
      await next(tester);
      await next(tester); // a estrutura é opcional

      await next(tester);
      expect(find.textContaining('Informe o preço'), findsOneWidget);

      await enterField(tester, 'Preço a partir de', '0');
      await next(tester);
      expect(find.text('O preço precisa ser maior que zero.'), findsOneWidget);
    });

    appTest('a revisão mostra o que foi preenchido antes de enviar', (
      tester,
      app,
    ) async {
      await openHallForm(tester);

      await fillUntilReview(tester);

      expect(find.text('Confira antes de enviar'), findsOneWidget);
      expect(find.text('Maria Oliveira'), findsOneWidget);
      expect(find.text('Espaço Crystal'), findsOneWidget);
      expect(find.text('Salvador, BA'), findsOneWidget);
      expect(find.text('150 pessoas'), findsOneWidget);
      expect(find.text('Casamentos'), findsOneWidget);
      expect(find.text('Wi-Fi'), findsOneWidget);
      expect(find.text(formatBrl(250000)), findsOneWidget);
      expect(find.text('Moderada'), findsOneWidget);
      // Nada foi enviado ainda.
      expect(app.state.vendor.status, VendorStatus.none);
    });

    appTest('"Voltar" retorna à etapa anterior mantendo o que foi digitado', (
      tester,
      app,
    ) async {
      await openHallForm(tester);
      await fillLegalStep(tester);
      await next(tester);

      await tapAndSettle(tester, find.widgetWithText(TextButton, 'Voltar'));

      expect(find.bySemanticsLabel('Etapa 1 de 6'), findsOneWidget);
      expect(find.text('Maria Oliveira'), findsOneWidget);
    });

    appTest('sair com dados preenchidos pede confirmação', (tester, app) async {
      await openHallForm(tester);
      await fillLegalStep(tester);

      await tapAndSettle(tester, find.byTooltip('Sair do cadastro'));
      expect(find.text('Sair sem enviar?'), findsOneWidget);

      await tapAndSettle(tester, find.text('Continuar preenchendo'));
      expect(find.bySemanticsLabel('Etapa 1 de 6'), findsOneWidget);

      await tapAndSettle(tester, find.byTooltip('Sair do cadastro'));
      await tapAndSettle(tester, find.text('Sair'));
      expect(
        find.widgetWithText(AppBar, 'O que você vai anunciar?'),
        findsOneWidget,
      );
    });

    appTest('sem nada preenchido, sai direto', (tester, app) async {
      await openHallForm(tester);

      await tapAndSettle(tester, find.byTooltip('Sair do cadastro'));

      expect(find.text('Sair sem enviar?'), findsNothing);
      expect(
        find.widgetWithText(AppBar, 'O que você vai anunciar?'),
        findsOneWidget,
      );
    });
  });

  group('análise e modo fornecedor', () {
    appTest('enviar o anúncio confirma e mostra a análise no perfil', (
      tester,
      app,
    ) async {
      await openHallForm(tester);
      await fillUntilReview(tester);

      await tapAndSettle(tester, filledButton('Enviar anúncio'));
      expect(find.text('Anúncio enviado!'), findsOneWidget);

      await tapAndSettle(tester, filledButton('Entendido'));

      expect(find.text('Análise em andamento'), findsOneWidget);
      expect(find.text('Tem um salão ou serviço?'), findsNothing);
      final listing = app.state.vendor.listings.single;
      expect(listing.title, 'Espaço Crystal');
      expect(listing.status, VendorListingStatus.pendingReview);
    });

    appTest('depois de aprovado, o modo fornecedor mostra os anúncios', (
      tester,
      app,
    ) async {
      await submitHall(tester);

      // No modo demonstração não há equipe para aprovar: o próprio app simula.
      await tapAndSettle(tester, find.text('Simular aprovação (demo)'));
      expect(find.text('Você é um fornecedor!'), findsOneWidget);

      await tapAndSettle(tester, find.text('Modo Fornecedor'));

      expect(find.text('Fornecedor aprovado'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Anúncios enviados'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Anúncios publicados'), findsOneWidget);
      expect(find.bySemanticsLabel('0 Em análise'), findsOneWidget);

      await tapAndSettle(tester, find.text('Modo Cliente'));
      expect(find.text('Dados Pessoais'), findsOneWidget);
    });

    appTest('o cadastro de fornecedor é da conta: some ao sair', (
      tester,
      app,
    ) async {
      await submitHall(tester);

      await scrollToAndTap(tester, find.text('Sair da conta'));
      await tapAndSettle(tester, find.text('Sair'));

      expect(app.state.vendor.status, VendorStatus.none);
      expect(app.state.vendor.listings, isEmpty);
    });
  });
}
