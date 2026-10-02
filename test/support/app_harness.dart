import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/app/app_state.dart';
import 'package:yvenist/app/yvenist_app.dart';

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

/// Toca em um item da barra de navegação inferior pelo rótulo acessível.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label).first);
  await tester.pumpAndSettle();
}
