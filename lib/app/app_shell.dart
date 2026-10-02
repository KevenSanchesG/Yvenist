import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/app/widgets/app_bottom_nav_bar.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/auth/presentation/auth_gate.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:yvenist/features/client/explore/presentation/pages/explore_page.dart';
import 'package:yvenist/features/client/home/presentation/pages/home_page.dart';
import 'package:yvenist/features/client/profile/presentation/pages/profile_page.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';
import 'package:yvenist/features/party_maker/presentation/pages/party_maker_entry_page.dart';
import 'package:yvenist/features/shared_features/chat/presentation/pages/chat_page.dart';

/// Estrutura principal: as cinco abas e a barra de navegação inferior.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Acima das abas porque a Home também o usa: tocar em uma categoria lá
      // aplica o filtro e abre a aba Explorar.
      create: (context) => ExploreController(context.read<CatalogRepository>()),
      child: const _ShellScaffold(),
    );
  }
}

class _ShellScaffold extends StatefulWidget {
  const _ShellScaffold();

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold> {
  // Uma aba só é construída quando é aberta pela primeira vez; depois fica
  // viva, guardando rolagem e estado. Evita carregar dados de abas que a
  // pessoa nunca visitou.
  final Set<AppTab> _visited = {AppTab.home};

  @override
  Widget build(BuildContext context) {
    final tabs = context.watch<AppTabController>();
    final current = tabs.current;
    _visited.add(current);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUi,
      child: PopScope(
        // O "voltar" do sistema, fora da Home, leva à Home em vez de fechar o
        // app: é o mesmo destino das setas de voltar das abas.
        canPop: current == AppTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) tabs.goTo(AppTab.home);
        },
        child: Scaffold(
          body: IndexedStack(
            index: current.index,
            children: [
              for (final tab in AppTab.values)
                _visited.contains(tab)
                    ? _tabRoot(tab)
                    : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar: AppBottomNavBar(
            current: current,
            onSelected: tabs.goTo,
          ),
          floatingActionButton: PartyTabButton(
            isSelected: current == AppTab.partyMaker,
            onPressed: () => tabs.goTo(AppTab.partyMaker),
          ),
          floatingActionButtonLocation: const PartyTabButtonLocation(),
          // O botão faz parte da barra: não entra nem sai com animação.
          floatingActionButtonAnimator:
              FloatingActionButtonAnimator.noAnimation,
        ),
      ),
    );
  }

  Widget _tabRoot(AppTab tab) {
    return switch (tab) {
      AppTab.home => const HomePage(),
      AppTab.explore => const ExplorePage(),
      AppTab.partyMaker => const _RequiresAccount(
        title: 'Monte a sua festa',
        message:
            'Entre para reunir salão, atrações e serviços em um só '
            'lugar e pedir o orçamento.',
        reason: 'Entre para montar a sua festa.',
        child: PartyMakerEntryPage(),
      ),
      AppTab.chat => const ChatPage(),
      AppTab.profile => const _RequiresAccount(
        title: 'Sua conta',
        message: 'Entre para ver seus dados, festas e favoritos.',
        reason: 'Entre para acessar a sua conta.',
        child: ProfilePage(),
      ),
    };
  }
}

/// Mostra [child] para quem está autenticado; para visitantes, explica o que a
/// aba oferece e convida a entrar.
class _RequiresAccount extends StatelessWidget {
  const _RequiresAccount({
    required this.title,
    required this.message,
    required this.reason,
    required this.child,
  });

  final String title;
  final String message;
  final String reason;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return switch (session.status) {
      SessionStatus.signedIn => child,
      SessionStatus.restoring => const Scaffold(body: LoadingView()),
      SessionStatus.restoreFailed => Scaffold(
        body: ErrorStateView(
          message:
              'Não foi possível verificar a sua sessão. '
              'Confira a conexão e tente de novo.',
          onRetry: session.restore,
        ),
      ),
      SessionStatus.signedOut => Scaffold(
        body: SafeArea(
          child: EmptyStateView(
            icon: Icons.account_circle_outlined,
            title: title,
            message: message,
            actionLabel: 'Entrar ou criar conta',
            onAction: () => ensureSignedIn(context, reason: reason),
          ),
        ),
      ),
    };
  }
}
