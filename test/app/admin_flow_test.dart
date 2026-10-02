import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/admin/data/in_memory_review_repository.dart';

import '../support/app_harness.dart';
import '../support/review_fixtures.dart';

Future<void> openQueue(WidgetTester tester) async {
  await openTab(tester, 'Perfil');
  await scrollToAndTap(tester, find.text('Fila de análise'));
}

/// O botão de um cartão da fila ("Aprovar", "Publicar" ou "Recusar").
Finder cardButton(String cardTitle, String label) {
  // O cartão é o Material mais próximo em volta do título.
  final card = find
      .ancestor(of: find.text(cardTitle), matching: find.byType(Material))
      .first;
  return find.descendant(
    of: card,
    // bySubtype: os botões do cartão são de tipos diferentes (contornado e
    // preenchido), e byType só casa com o tipo exato.
    matching: find.ancestor(
      of: find.text(label),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
}

/// O botão de confirmação de um diálogo.
Finder dialogButton(String label) {
  return find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, label),
  );
}

void main() {
  group('acesso', () {
    appTest('conta comum não vê a administração', (tester, app) async {
      await openTab(tester, 'Perfil');

      expect(find.text('Fila de análise'), findsNothing);
      expect(find.text('ADMINISTRAÇÃO'), findsNothing);
    });

    appTest(
      'conta de administração encontra a fila no perfil',
      (tester, app) async {
        await openQueue(tester);

        expect(find.widgetWithText(AppBar, 'Fila de análise'), findsOneWidget);
        expect(find.text('Fornecedores (1)'), findsOneWidget);
        expect(find.text('Anúncios (2)'), findsOneWidget);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'se o servidor negar o acesso, a tela diz e deixa tentar de novo',
      (tester, app) async {
        await openQueue(tester);

        expect(
          find.text('Você não tem permissão para esta ação.'),
          findsOneWidget,
        );
        expect(filledButton('Tentar novamente'), findsOneWidget);
      },
      dependencies: () => adminDependencies(
        ControllableReviews()..loadFailure = const ForbiddenFailure(),
      ),
    );

    appTest(
      'tentar de novo depois de uma falha carrega a fila',
      (tester, app) async {
        final reviews = app.dependencies.reviews as ControllableReviews;
        await openQueue(tester);
        expect(find.text('Não foi possível carregar'), findsOneWidget);

        reviews.loadFailure = null;
        await tapAndSettle(tester, filledButton('Tentar novamente'));

        expect(find.text('Maria Oliveira'), findsOneWidget);
      },
      dependencies: () => adminDependencies(
        ControllableReviews(sampleReviewQueue())
          ..loadFailure = const NetworkFailure(),
      ),
    );

    appTest(
      'fila vazia explica o que apareceria ali',
      (tester, app) async {
        await openQueue(tester);

        expect(find.text('Nenhum cadastro aguardando'), findsOneWidget);
        expect(find.text('Fornecedores (0)'), findsOneWidget);

        await tapAndSettle(tester, find.text('Anúncios (0)'));
        expect(find.text('Nenhum anúncio aguardando'), findsOneWidget);
        expect(filledButton('Atualizar'), findsOneWidget);
      },
      dependencies: () => adminDependencies(InMemoryReviewRepository()),
    );
  });

  group('cadastros de fornecedor', () {
    appTest(
      'o cartão mostra quem é e o que espera junto',
      (tester, app) async {
        await openQueue(tester);

        expect(find.text('Maria Oliveira'), findsOneWidget);
        // O documento completo, pontuado: é o que a análise confere.
        expect(find.text('Pessoa física · CPF 529.982.247-25'), findsOneWidget);
        expect(
          find.text('Em análise com este cadastro: Espaço Crystal.'),
          findsOneWidget,
        );
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'aprovar publica junto o anúncio que veio com o cadastro',
      (tester, app) async {
        await openQueue(tester);

        await tapAndSettle(tester, cardButton('Maria Oliveira', 'Aprovar'));
        expect(find.text('Aprovar cadastro?'), findsOneWidget);
        expect(
          find.text('Publicar também o anúncio "Espaço Crystal"'),
          findsOneWidget,
        );
        await tapAndSettle(tester, dialogButton('Aprovar'));

        expect(find.text('Cadastro aprovado.'), findsOneWidget);
        expect(find.text('Nenhum cadastro aguardando'), findsOneWidget);
        // Só sobrou o anúncio do outro fornecedor.
        expect(find.text('Anúncios (1)'), findsOneWidget);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'aprovar sem publicar deixa o anúncio na fila, já liberado',
      (tester, app) async {
        await openQueue(tester);

        await tapAndSettle(tester, cardButton('Maria Oliveira', 'Aprovar'));
        await tapAndSettle(tester, find.byType(Checkbox));
        await tapAndSettle(tester, dialogButton('Aprovar'));
        await waitSnackBarLeave(tester);

        await tapAndSettle(tester, find.text('Anúncios (2)'));
        final publish = tester.widget<ButtonStyleButton>(
          cardButton('Espaço Crystal', 'Publicar'),
        );
        expect(publish.onPressed, isNotNull);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'desistir da aprovação não muda nada',
      (tester, app) async {
        await openQueue(tester);

        await tapAndSettle(tester, cardButton('Maria Oliveira', 'Aprovar'));
        await tapAndSettle(tester, dialogButton('Cancelar'));

        expect(find.text('Maria Oliveira'), findsOneWidget);
        expect(find.text('Fornecedores (1)'), findsOneWidget);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'recusar exige o motivo e leva junto o anúncio do cadastro',
      (tester, app) async {
        await openQueue(tester);

        await tapAndSettle(tester, cardButton('Maria Oliveira', 'Recusar'));
        expect(find.text('Recusar cadastro?'), findsOneWidget);
        expect(
          find.textContaining('anúncios em análise deste cadastro também'),
          findsOneWidget,
        );

        // Sem motivo não envia.
        await tapAndSettle(tester, dialogButton('Recusar'));
        expect(find.text('Explique o motivo da recusa.'), findsOneWidget);

        await enterField(tester, 'Motivo da recusa', 'Documento ilegível.');
        await tapAndSettle(tester, dialogButton('Recusar'));

        expect(find.text('Cadastro recusado.'), findsOneWidget);
        expect(find.text('Nenhum cadastro aguardando'), findsOneWidget);
        expect(find.text('Anúncios (1)'), findsOneWidget);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'se outra pessoa já decidiu, avisa e tira o cadastro da tela',
      (tester, app) async {
        await openQueue(tester);
        // Outro administrador decide enquanto esta tela está aberta.
        await app.dependencies.reviews.approveVendor(
          'vendor-1',
          publishListings: true,
        );

        await tapAndSettle(tester, cardButton('Maria Oliveira', 'Aprovar'));
        await tapAndSettle(tester, dialogButton('Aprovar'));

        expect(find.text('Este item já foi analisado.'), findsOneWidget);
        expect(find.text('Maria Oliveira'), findsNothing);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );
  });

  group('anúncios', () {
    appTest(
      'o cartão mostra o anúncio, de quem é e os detalhes',
      (tester, app) async {
        await openQueue(tester);
        await tapAndSettle(tester, find.text('Anúncios (2)'));

        expect(find.text('Espaço Crystal'), findsOneWidget);
        // A categoria aparece pelo nome do catálogo, não pela chave.
        expect(
          find.text('Salões · Campo Grande, Rio de Janeiro, RJ'),
          findsOneWidget,
        );
        expect(
          find.text('Buffet e Bar · Campo Grande, Rio de Janeiro, RJ'),
          findsOneWidget,
        );
        expect(find.text('A partir de R\$ 2.500,00'), findsNWidgets(2));
        expect(
          find.text('Fornecedor: Maria Oliveira · enviado em 01/10/2026'),
          findsOneWidget,
        );

        await tapAndSettle(tester, find.text('Ver detalhes').first);
        for (final detail in [
          'Descrição: Salão amplo, climatizado, com cozinha equipada.',
          'Capacidade: 150 pessoas',
          'Área: 300 m²',
          'Eventos: Casamentos, 15 anos',
          'Estrutura: Cozinha equipada, Wi-Fi',
          'Cancelamento: Moderada. Reembolso de 50% até 7 dias antes.',
        ]) {
          expect(find.text(detail, findRichText: true), findsOneWidget);
        }
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'anúncio de cadastro ainda em análise não pode ser publicado',
      (tester, app) async {
        await openQueue(tester);
        await tapAndSettle(tester, find.text('Anúncios (2)'));

        final publish = tester.widget<ButtonStyleButton>(
          cardButton('Espaço Crystal', 'Publicar'),
        );
        expect(publish.onPressed, isNull);
        expect(
          find.textContaining('O cadastro deste fornecedor ainda não foi'),
          findsOneWidget,
        );
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'publicar pede confirmação e tira o anúncio da fila',
      (tester, app) async {
        await openQueue(tester);
        await tapAndSettle(tester, find.text('Anúncios (2)'));

        await scrollToAndTap(tester, cardButton('Buffet da Ana', 'Publicar'));
        expect(find.text('Publicar anúncio?'), findsOneWidget);
        await tapAndSettle(tester, dialogButton('Publicar'));

        expect(find.text('Anúncio publicado.'), findsOneWidget);
        expect(find.text('Buffet da Ana'), findsNothing);
        expect(find.text('Anúncios (1)'), findsOneWidget);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'recusar um anúncio pede o motivo',
      (tester, app) async {
        await openQueue(tester);
        await tapAndSettle(tester, find.text('Anúncios (2)'));

        await scrollToAndTap(tester, cardButton('Buffet da Ana', 'Recusar'));
        expect(find.text('Recusar anúncio?'), findsOneWidget);
        await enterField(tester, 'Motivo da recusa', 'Fotos insuficientes.');
        await tapAndSettle(tester, dialogButton('Recusar'));

        expect(find.text('Anúncio recusado.'), findsOneWidget);
        expect(find.text('Buffet da Ana'), findsNothing);
      },
      dependencies: () => adminDependencies(sampleReviewQueue()),
    );

    appTest(
      'falha ao decidir aparece como aviso e o anúncio continua na fila',
      (tester, app) async {
        final reviews = app.dependencies.reviews as ControllableReviews;
        await openQueue(tester);
        await tapAndSettle(tester, find.text('Anúncios (2)'));
        reviews.decisionFailure = const NetworkFailure();

        await scrollToAndTap(tester, cardButton('Buffet da Ana', 'Publicar'));
        await tapAndSettle(tester, dialogButton('Publicar'));

        expect(find.text(const NetworkFailure().message), findsOneWidget);
        expect(find.text('Buffet da Ana'), findsOneWidget);
      },
      dependencies: () =>
          adminDependencies(ControllableReviews(sampleReviewQueue())),
    );
  });
}
