import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/storage/theme_preference_storage.dart';

import '../support/app_harness.dart';

/// A escolha de tema: onde fica, o que muda e o que é guardado.
void main() {
  ThemeMode selectedOption(WidgetTester tester) {
    return tester
        .widget<RadioGroup<ThemeMode>>(find.byType(RadioGroup<ThemeMode>))
        .groupValue!;
  }

  Future<void> openAppearance(WidgetTester tester) async {
    await openTab(tester, 'Perfil');
    await scrollToAndTap(tester, find.text('Aparência'));
  }

  group('aparência', () {
    appTest('fica nas configurações do perfil e começa no tema do aparelho', (
      tester,
      app,
    ) async {
      await openAppearance(tester);

      expect(find.widgetWithText(AppBar, 'Aparência'), findsOneWidget);
      expect(find.text('Padrão do aparelho'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);
      expect(selectedOption(tester), ThemeMode.system);
      expect(currentBrightness(tester), Brightness.light);
    });

    final storage = InMemoryThemePreferenceStorage();
    appTest(
      'escolher Escuro muda o app na hora e guarda a escolha',
      (tester, app) async {
        await openAppearance(tester);

        await tapAndSettle(tester, find.text('Escuro'));

        // A própria tela é a prévia: não há botão de salvar.
        expect(selectedOption(tester), ThemeMode.dark);
        expect(currentBrightness(tester), Brightness.dark);
        expect(await storage.read(), ThemeMode.dark);

        // E as outras telas acompanham.
        await tapAndSettle(tester, find.byType(BackButton));
        expect(find.text('Conta Demonstração'), findsOneWidget);
        expect(currentBrightness(tester), Brightness.dark);

        // Voltar ao claro desfaz.
        await scrollToAndTap(tester, find.text('Aparência'));
        await tapAndSettle(tester, find.text('Claro'));
        expect(currentBrightness(tester), Brightness.light);
        expect(await storage.read(), ThemeMode.light);
      },
      dependencies: () => demoDependencies(themePreferences: storage),
    );

    appTest(
      'a escolha guardada já vale quando o app abre',
      (tester, app) async {
        expect(currentBrightness(tester), Brightness.dark);

        await openAppearance(tester);
        expect(selectedOption(tester), ThemeMode.dark);
      },
      dependencies: () => demoDependencies(
        themePreferences: InMemoryThemePreferenceStorage(ThemeMode.dark),
      ),
    );

    appTest('no padrão do aparelho, o app acompanha o sistema', (
      tester,
      app,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();

      expect(currentBrightness(tester), Brightness.dark);

      // Uma escolha explícita vale mais que o sistema.
      await openAppearance(tester);
      await tapAndSettle(tester, find.text('Claro'));
      expect(currentBrightness(tester), Brightness.light);

      await tapAndSettle(tester, find.text('Padrão do aparelho'));
      expect(currentBrightness(tester), Brightness.dark);
    });

    appTest('quem não entrou em uma conta também escolhe o tema', (
      tester,
      app,
    ) async {
      await openTab(tester, 'Perfil');
      expect(find.text('Entrar ou criar conta'), findsOneWidget);

      await tapAndSettle(tester, find.text('Aparência'));
      await tapAndSettle(tester, find.text('Escuro'));

      expect(currentBrightness(tester), Brightness.dark);
      expect(app.state.theme.mode, ThemeMode.dark);
    }, signedIn: false);

    appTest('a escolha é do aparelho: continua valendo depois de sair da '
        'conta', (tester, app) async {
      await openAppearance(tester);
      await tapAndSettle(tester, find.text('Escuro'));
      await tapAndSettle(tester, find.byType(BackButton));

      await scrollToAndTap(tester, find.text('Sair da conta'));
      await tapAndSettle(tester, find.text('Sair'));

      expect(find.text('O que vamos comemorar?'), findsOneWidget);
      expect(currentBrightness(tester), Brightness.dark);
    });
  });
}
