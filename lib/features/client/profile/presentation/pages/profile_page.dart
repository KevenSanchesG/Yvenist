import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/config/app_config.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/admin/presentation/pages/review_queue_page.dart';
import 'package:yvenist/features/auth/domain/entities/app_user.dart';
import 'package:yvenist/features/auth/presentation/controllers/session_controller.dart';
import 'package:yvenist/features/client/favorites/presentation/controllers/favorites_controller.dart';
import 'package:yvenist/features/client/favorites/presentation/pages/favorites_page.dart';
import 'package:yvenist/features/client/profile/presentation/pages/personal_data_page.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/presentation/controllers/party_maker_controller.dart';
import 'package:yvenist/features/shared_features/appearance/presentation/pages/appearance_page.dart';
import 'package:yvenist/features/shared_features/legal/presentation/pages/legal_page.dart';
import 'package:yvenist/features/shared_features/payments/presentation/pages/payment_methods_page.dart';
import 'package:yvenist/features/shared_features/security/presentation/pages/security_page.dart';
import 'package:yvenist/features/vendor/domain/vendor_models.dart';
import 'package:yvenist/features/vendor/onboarding/presentation/pages/vendor_welcome_page.dart';
import 'package:yvenist/features/vendor/presentation/controllers/vendor_controller.dart';

/// Aba Perfil. Mostra a conta em dois modos: cliente e, para quem foi
/// aprovado como fornecedor, o modo fornecedor.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _vendorMode = false;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();

  /// O cabeçalho já saiu de baixo da barra de status? A partir daí o resto da
  /// tela passaria por baixo do relógio.
  final ValueNotifier<bool> _headerLeftStatusBar = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _headerLeftStatusBar.dispose();
    super.dispose();
  }

  void _onScroll() {
    final header = _headerKey.currentContext?.findRenderObject();
    if (header is! RenderBox || !header.hasSize) return;

    // Onde termina a parte reta do degradê: sem a metade do seletor de modo,
    // que fica abaixo dele, e sem os cantos arredondados.
    final gradientEnd =
        header.size.height - _ModeToggle.height / 2 - _Header.cornerRadius;
    final statusBar = MediaQuery.paddingOf(context).top;
    _headerLeftStatusBar.value = _scroll.offset > gradientEnd - statusBar;
  }

  void _push(Widget page) {
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openParties() {
    context.read<PartyMakerController>().clearActiveParty();
    context.read<AppTabController>().goTo(AppTab.partyMaker);
  }

  void _selectVendorMode() {
    if (context.read<VendorController>().isApproved) {
      setState(() => _vendorMode = true);
      return;
    }
    showAppSnackBar(
      context,
      'O modo fornecedor fica disponível depois que o seu anúncio é aprovado.',
    );
  }

  Future<void> _confirmSignOut() async {
    final session = context.read<SessionController>();
    final tabs = context.read<AppTabController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você vai precisar entrar de novo para ver suas '
          'festas e favoritos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await session.signOut();
    tabs.goTo(AppTab.home);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final vendor = context.watch<VendorController>();
    // A sessão pode terminar com a aba aberta; o shell troca a tela em seguida.
    if (user == null) return const SizedBox.shrink();

    // Se a aprovação for retirada, o modo fornecedor deixa de valer.
    final vendorMode = _vendorMode && vendor.isApproved;
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.backgroundMuted,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Enquanto o cabeçalho escuro está no topo, o relógio e os
                // ícones da barra de status ficam brancos; rolando a tela,
                // voltam a ser os do tema.
                AnnotatedRegion<SystemUiOverlayStyle>(
                  value: AppTheme.systemUiOnDarkHeader(context),
                  child: _Header(
                    key: _headerKey,
                    user: user,
                    vendorMode: vendorMode,
                    onClientMode: () => setState(() => _vendorMode = false),
                    onVendorMode: _selectVendorMode,
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vendorMode)
                        ..._vendorContent(vendor)
                      else
                        ..._clientContent(vendor),
                      const SizedBox(height: 20),
                      if (user.isAdmin) ..._adminContent(),
                      ..._commonFooter(),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _StatusBarBackdrop(visible: _headerLeftStatusBar),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Modo cliente
  // ---------------------------------------------------------
  List<Widget> _clientContent(VendorController vendor) {
    final parties = context.watch<PartyMakerController>().parties;
    final favorites = context.watch<FavoritesController>().count;
    final planning = parties
        .where(
          (p) =>
              p.status == PartyStatus.draft || p.status == PartyStatus.planning,
        )
        .length;
    final quoted = parties.where((p) => p.status == PartyStatus.locked).length;

    return [
      _DashboardCard(
        items: [
          _StatItem(
            value: '$planning',
            label: 'Festas em\nplanejamento',
            onTap: _openParties,
          ),
          _StatItem(
            value: '$favorites',
            label: 'Favoritos\nsalvos',
            onTap: () => _push(const FavoritesPage()),
          ),
          _StatItem(
            value: '$quoted',
            label: 'Orçamentos\nsolicitados',
            onTap: _openParties,
          ),
        ],
      ),
      const SizedBox(height: 24),
      _VendorBanner(
        vendor: vendor,
        onStart: () => _push(const VendorWelcomePage()),
        onOpenVendorMode: () => setState(() => _vendorMode = true),
      ),
      const SizedBox(height: 24),
      const _SectionTitle('Minha conta'),
      _MenuCard(
        children: [
          _MenuItem(
            icon: Icons.person_outline,
            title: 'Dados Pessoais',
            onTap: () => _push(const PersonalDataPage()),
          ),
          const _MenuItem(
            icon: Icons.location_on_outlined,
            title: 'Endereços de Eventos',
          ),
          _MenuItem(
            icon: Icons.credit_card,
            title: 'Formas de Pagamento',
            onTap: () => _push(const PaymentMethodsPage()),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Gestão'),
      _MenuCard(
        children: [
          _MenuItem(
            icon: Icons.event_note,
            title: 'Minhas Festas',
            onTap: _openParties,
          ),
          const _MenuItem(
            icon: Icons.receipt_long,
            title: 'Histórico de Pagamentos',
          ),
          const _MenuItem(icon: Icons.star_border, title: 'Minhas Avaliações'),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------
  // Modo fornecedor
  // ---------------------------------------------------------
  List<Widget> _vendorContent(VendorController vendor) {
    return [
      _DashboardCard(
        items: [
          _StatItem(
            value: '${vendor.listings.length}',
            label: 'Anúncios\nenviados',
          ),
          _StatItem(
            value: '${vendor.countListings(VendorListingStatus.published)}',
            label: 'Anúncios\npublicados',
          ),
          _StatItem(
            value: '${vendor.countListings(VendorListingStatus.pendingReview)}',
            label: 'Em\nanálise',
          ),
        ],
      ),
      const SizedBox(height: 24),
      const _SectionTitle('Meu negócio'),
      _MenuCard(
        children: [
          _MenuItem(
            icon: Icons.add_business_outlined,
            title: 'Anunciar outro espaço',
            onTap: () => _push(const VendorWelcomePage()),
          ),
          const _MenuItem(icon: Icons.campaign, title: 'Meus Anúncios'),
          const _MenuItem(
            icon: Icons.calendar_month,
            title: 'Agenda e Disponibilidade',
          ),
        ],
      ),
      const SizedBox(height: 20),
      const _SectionTitle('Financeiro'),
      const _MenuCard(
        children: [
          _MenuItem(icon: Icons.attach_money, title: 'Extrato e Saques'),
          _MenuItem(icon: Icons.account_balance, title: 'Dados Bancários'),
        ],
      ),
    ];
  }

  // ---------------------------------------------------------
  // Administração (só para contas de administração)
  // ---------------------------------------------------------
  List<Widget> _adminContent() {
    return [
      const _SectionTitle('Administração'),
      _MenuCard(
        children: [
          _MenuItem(
            icon: Icons.fact_check_outlined,
            title: 'Fila de análise',
            onTap: () => _push(const ReviewQueuePage()),
          ),
        ],
      ),
      const SizedBox(height: 20),
    ];
  }

  // ---------------------------------------------------------
  // Rodapé comum
  // ---------------------------------------------------------
  List<Widget> _commonFooter() {
    return [
      const _SectionTitle('Configurações e suporte'),
      _MenuCard(
        children: [
          // Primeiro da lista: é a única configuração que muda o app inteiro,
          // e fica junto das outras, onde uma configuração é procurada.
          _MenuItem(
            icon: Icons.brightness_6_outlined,
            title: 'Aparência',
            onTap: () => _push(const AppearancePage()),
          ),
          _MenuItem(
            icon: Icons.lock_outline,
            title: 'Segurança',
            onTap: () => _push(const SecurityPage()),
          ),
          const _MenuItem(icon: Icons.help_outline, title: 'Central de Ajuda'),
          _MenuItem(
            icon: Icons.description_outlined,
            title: 'Termos e Política',
            onTap: () => _push(const LegalPage()),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Center(
        child: TextButton.icon(
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sair da conta'),
          style: TextButton.styleFrom(foregroundColor: context.colors.danger),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Versão ${AppConfig.appVersion}',
          style: context.text.caption,
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------
// Cabeçalho com o seletor de modo
// ---------------------------------------------------------

/// O fundo da barra de status depois que o cabeçalho sai de baixo dela.
///
/// O cabeçalho do perfil vai por baixo da barra de status, e o resto da tela
/// rola atrás dele: sem este fundo, os títulos e os itens passariam por baixo
/// do relógio.
class _StatusBarBackdrop extends StatelessWidget {
  const _StatusBarBackdrop({required this.visible});

  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, isVisible, child) => AnimatedOpacity(
          key: const ValueKey('status-bar-backdrop'),
          opacity: isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: child,
        ),
        // Sobre o fundo da tela, o relógio volta a ter a cor do tema.
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemUi(context),
          child: ColoredBox(
            color: colors.backgroundMuted,
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.paddingOf(context).top,
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    super.key,
    required this.user,
    required this.vendorMode,
    required this.onClientMode,
    required this.onVendorMode,
  });

  static const double cornerRadius = 30;

  final AppUser user;
  final bool vendorMode;
  final VoidCallback onClientMode;
  final VoidCallback onVendorMode;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final text = context.text;
    // Degradês escuros o bastante para o nome e o e-mail, em branco. São os
    // mesmos nos dois temas.
    final gradient = vendorMode
        ? AppColors.vendorGradient
        : AppColors.clientGradient;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // O seletor de modo fica metade sobre o cabeçalho, metade abaixo. A
        // margem reserva essa metade de baixo dentro da pilha: o que é
        // desenhado fora dos limites de um widget não recebe toques.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: _ModeToggle.height / 2),
          padding: EdgeInsets.fromLTRB(20, topPadding + 32, 20, 56),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(cornerRadius),
            ),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.onGradient,
                child: ExcludeSemantics(
                  child: Text(
                    user.initials,
                    style: text.sectionTitle.copyWith(
                      fontSize: 28,
                      color: gradient.first,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                style: text.sectionTitle.copyWith(
                  fontSize: 20,
                  color: AppColors.onGradient,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                vendorMode ? 'Fornecedor aprovado' : user.email,
                style: text.caption.copyWith(color: AppColors.onGradient),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 24,
          right: 24,
          child: _ModeToggle(
            vendorMode: vendorMode,
            onClientMode: onClientMode,
            onVendorMode: onVendorMode,
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.vendorMode,
    required this.onClientMode,
    required this.onVendorMode,
  });

  static const double height = 52;

  final bool vendorMode;
  final VoidCallback onClientMode;
  final VoidCallback onVendorMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(height / 2),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            _ModeOption(
              label: 'Modo Cliente',
              selected: !vendorMode,
              color: colors.primary,
              onTap: onClientMode,
            ),
            _ModeOption(
              label: 'Modo Fornecedor',
              selected: vendorMode,
              color: colors.vendor,
              onTap: onVendorMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          // O destaque passa de um lado para o outro, em vez de saltar.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: selected
                ? colors.tint(color)
                : colors.tint(color).withValues(alpha: 0),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: context.text.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? color : colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Situação como fornecedor
// ---------------------------------------------------------

class _VendorBanner extends StatelessWidget {
  const _VendorBanner({
    required this.vendor,
    required this.onStart,
    required this.onOpenVendorMode,
  });

  final VendorController vendor;
  final VoidCallback onStart;
  final VoidCallback onOpenVendorMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return switch (vendor.status) {
      VendorStatus.none => _PromoBanner(
        title: 'Tem um salão ou serviço?',
        subtitle: 'Anuncie no Yvenist sem pagar nada por isso.',
        colors: AppColors.vendorGradient,
        icon: Icons.storefront,
        onTap: onStart,
      ),
      VendorStatus.pendingReview => _StatusNotice(
        icon: Icons.hourglass_top,
        color: colors.warning,
        title: 'Análise em andamento',
        message: 'Estamos verificando os dados do seu anúncio.',
        // Só existe no modo demonstração, onde não há quem aprove.
        actionLabel: vendor.canSimulateApproval
            ? 'Simular aprovação (demo)'
            : null,
        onAction: vendor.isBusy ? null : vendor.simulateApproval,
      ),
      VendorStatus.rejected => _StatusNotice(
        icon: Icons.error_outline,
        color: colors.danger,
        title: 'Cadastro não aprovado',
        message:
            vendor.profile?.rejectionReason ??
            'Revise os dados e envie de novo.',
        actionLabel: 'Corrigir e reenviar',
        onAction: onStart,
      ),
      VendorStatus.approved => _PromoBanner(
        title: 'Você é um fornecedor!',
        subtitle: 'Abra o Modo Fornecedor para acompanhar seus anúncios.',
        colors: AppColors.successGradient,
        icon: Icons.check_circle,
        onTap: onOpenVendorMode,
      ),
    };
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.tint(color),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(message, style: text.caption),
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.text.body.copyWith(
                            color: AppColors.onGradient,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: context.text.caption.copyWith(
                            color: AppColors.onGradient,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: Icon(icon, color: AppColors.onGradient),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Peças de layout
// ---------------------------------------------------------

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, item) in items.indexed) ...[
              if (index > 0)
                const VerticalDivider(width: 1, indent: 16, endIndent: 16),
              Expanded(child: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label, this.onTap});

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: context.text.sectionTitle.copyWith(
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.caption.copyWith(height: 1.2),
          ),
        ],
      ),
    );

    // O rótulo substitui os dois textos soltos. O InkWell fica fora do
    // ExcludeSemantics para o toque também existir para leitores de tela.
    final described = ExcludeSemantics(child: content);
    return Semantics(
      button: onTap != null,
      label: '$value ${label.replaceAll('\n', ' ')}',
      child: onTap == null
          ? described
          : InkWell(onTap: onTap, child: described),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: context.text.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 56),
            child,
          ],
        ],
      ),
    );
  }
}

/// Item de menu. Sem [onTap] é uma função prevista e ainda não disponível:
/// aparece como "Em breve" e não responde ao toque.
class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isAvailable = onTap != null;
    final colors = context.colors;
    final text = context.text;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: colors.textSecondary, size: 22),
      title: Text(
        title,
        style: text.body.copyWith(
          fontWeight: FontWeight.w500,
          color: isAvailable ? colors.textPrimary : colors.textSecondary,
        ),
      ),
      trailing: isAvailable
          ? Icon(Icons.chevron_right, size: 18, color: colors.textSecondary)
          : Text('Em breve', style: text.caption),
    );
  }
}
