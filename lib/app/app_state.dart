import 'dart:async';

import 'package:yvenist/app/app_dependencies.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/theme_mode_controller.dart';
import 'package:yvenist/core/utils/id_generator.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/vendor/presentation/controllers/vendor_controller.dart';

/// Controllers que vivem durante todo o app.
///
/// São criados antes do `runApp` e ligados aqui: quando a sessão muda (login,
/// logout, sessão expirada), favoritos, festas e cadastro de fornecedor passam
/// a ser os da nova conta. Fazer essa ligação fora da árvore de widgets evita
/// notificar ouvintes durante a construção de uma tela.
class AppState {
  AppState(AppDependencies dependencies, {IdGenerator? ids})
    : theme = ThemeModeController(dependencies.themePreferences),
      session = SessionController(dependencies.auth),
      tabs = AppTabController(),
      favorites = FavoritesController(dependencies.favorites),
      parties = PartyMakerController(
        repository: dependencies.parties,
        ids: ids ?? UuidGenerator(),
      ),
      vendor = VendorController(dependencies.vendors) {
    dependencies.apiClient?.onSessionExpired = session.handleSessionExpired;
    session.addListener(_onSessionChanged);
  }

  /// A escolha de tema: é do aparelho, e não de quem está logado.
  final ThemeModeController theme;
  final SessionController session;
  final AppTabController tabs;
  final FavoritesController favorites;
  final PartyMakerController parties;
  final VendorController vendor;

  bool _hasSynced = false;
  String? _syncedUserId;

  /// Lê a escolha de tema e recupera a sessão guardada no aparelho. Chamado
  /// uma vez, ao abrir o app.
  Future<void> start() async {
    await theme.load();
    await session.restore();
  }

  void _onSessionChanged() {
    if (session.status == SessionStatus.restoring) return;

    final userId = session.user?.id;
    if (_hasSynced && userId == _syncedUserId) return;
    _hasSynced = true;
    _syncedUserId = userId;

    unawaited(favorites.setUser(userId));
    unawaited(parties.setOwner(userId));
    unawaited(vendor.setUser(userId));
  }

  void dispose() {
    session.removeListener(_onSessionChanged);
    theme.dispose();
    session.dispose();
    tabs.dispose();
    favorites.dispose();
    parties.dispose();
    vendor.dispose();
  }
}
