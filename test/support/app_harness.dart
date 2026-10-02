import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/widgets/app_bottom_nav_bar.dart';
import 'package:yvenist/app/yvenist_app.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/features/admin/data/in_memory_review_repository.dart';
import 'package:yvenist/features/admin/domain/review_repository.dart';
import 'package:yvenist/features/auth/data/in_memory_auth_repository.dart';
import 'package:yvenist/features/auth/domain/repositories/auth_repository.dart';
import 'package:yvenist/features/catalog/data/in_memory_catalog_repository.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/favorites/data/in_memory_favorites_repository.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/vendor/data/in_memory_vendor_repository.dart';

import 'visual_harness.dart';

/// O app inteiro montado para um teste, com as dependências em memória.
class TestApp {
  TestApp._(this.dependencies, this.state);

  final AppDependencies dependencies;
  final AppState state;
}

/// Sobe o app em modo demonstração dentro do teste e espera a primeira tela.
///
/// Com [signedIn] falso, o app começa como visitante (sem conta).
Future<TestApp> pumpYvenistApp(
  WidgetTester tester, {
  bool signedIn = true,
  AppDependencies? dependencies,
}) async {
  final deps = dependencies ?? AppDependencies.demo(startSignedIn: signedIn);
  final state = AppState(deps);
  addTearDown(state.dispose);

  await state.start();
  await tester.pumpWidget(YvenistApp(dependencies: deps, state: state));
  await tester.pumpAndSettle();
  return TestApp._(deps, state);
}

/// Declara um teste que sobe o app inteiro na tela de um celular.
///
/// [dependencies] troca as implementações em memória padrão, para simular
/// falhas (use [demoDependencies] para trocar só uma delas).
void appTest(
  String description,
  Future<void> Function(WidgetTester tester, TestApp app) body, {
  bool signedIn = true,
  AppDependencies Function()? dependencies,
  double? textScale,
}) {
  testWidgets(description, (tester) async {
    usePhoneScreen(tester);
    if (textScale != null) {
      // O tamanho de fonte escolhido nas configurações do aparelho.
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final app = await pumpYvenistApp(
      tester,
      signedIn: signedIn,
      dependencies: dependencies?.call(),
    );
    await body(tester, app);
  });
}

/// As dependências do modo demonstração, com a possibilidade de trocar o
/// catálogo, a autenticação ou a fila de análise por outra versão (uma que
/// falha, ou uma já com itens).
AppDependencies demoDependencies({
  InMemoryAuthRepository? auth,
  AuthRepository? authOverride,
  CatalogRepository? catalog,
  ReviewRepository? reviews,
}) {
  final accounts = auth ?? InMemoryAuthRepository();
  return AppDependencies(
    config: const AppConfig(),
    auth: authOverride ?? accounts,
    catalog: catalog ?? InMemoryCatalogRepository(),
    favorites: InMemoryFavoritesRepository(
      currentUserId: () => accounts.currentUserId,
    ),
    parties: InMemoryPartyRepository(),
    vendors: InMemoryVendorRepository(
      currentUserId: () => accounts.currentUserId,
    ),
    reviews: reviews ?? InMemoryReviewRepository(),
  );
}

/// Um botão da navegação inferior, pelo rótulo acessível ("Início",
/// "Explorar", "Minhas festas", "Chat" ou "Perfil").
///
/// Procura só na barra e no botão central: o título de uma tela pode ter o
/// mesmo texto de uma aba.
Finder tabButton(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is AppBottomNavBar || widget is PartyTabButton,
    ),
    matching: find.bySemanticsLabel(label),
  );
}

/// Toca em um item da barra de navegação inferior pelo rótulo acessível.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(tabButton(label));
  await tester.pumpAndSettle();
}

/// Toca e espera a tela estabilizar.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Rola até [finder] ficar visível, toca e espera a tela estabilizar.
Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tapAndSettle(tester, finder);
}

/// Digita em um campo de formulário identificado pelo rótulo.
Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

/// Espera o aviso (SnackBar) sair da tela. Ele fica 4 segundos por cima do
/// rodapé, e um toque ali acertaria o aviso em vez do botão.
Future<void> waitSnackBarLeave(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// O botão principal de um formulário, pelo texto.
Finder filledButton(String label) => find.widgetWithText(FilledButton, label);

/// Entra com a conta de demonstração a partir da tela de login já aberta.
Future<void> signInWithDemoAccount(WidgetTester tester) async {
  await enterField(tester, 'E-mail', InMemoryAuthRepository.demoEmail);
  await enterField(tester, 'Senha', InMemoryAuthRepository.demoPassword);
  await tapAndSettle(tester, filledButton('Entrar'));
}
