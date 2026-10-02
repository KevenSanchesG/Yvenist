import 'package:flutter/foundation.dart';

/// Abas da navegação principal, na ordem em que aparecem na barra inferior.
enum AppTab { home, explore, partyMaker, chat, profile }

/// Aba selecionada na navegação principal.
///
/// Qualquer tela troca de aba por aqui (`context.read<AppTabController>()`),
/// sem precisar conhecer o widget que desenha a barra.
class AppTabController extends ChangeNotifier {
  AppTab _current = AppTab.home;

  AppTab get current => _current;

  void goTo(AppTab tab) {
    if (tab == _current) return;
    _current = tab;
    notifyListeners();
  }
}
