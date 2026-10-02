import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/features/auth/presentation/auth_gate.dart';
import 'package:yvenist/features/catalog/domain/entities/catalog_filters.dart';
import 'package:yvenist/features/client/favorites/presentation/pages/favorites_page.dart';
import 'package:yvenist/features/client/search/presentation/pages/search_page.dart';
import 'package:yvenist/features/client/shared/catalog_presentation.dart';
import 'package:yvenist/features/client/shared/listing_search_controller.dart';
import 'package:yvenist/features/shared_features/notifications/presentation/pages/notifications_page.dart';

/// Cabeçalho da Home: busca, atalhos de favoritos e notificações, e as
/// categorias como atalhos para a aba Explorar.
class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.categories,
    required this.eventTypes,
  });

  final List<CatalogCategory> categories;
  final List<EventType> eventTypes;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final ScrollController _scrollController = ScrollController();
  int _activeDot = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateDots);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateDots() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final progress = _scrollController.offset / maxScroll;
    final dot = progress < 0.33 ? 0 : (progress < 0.66 ? 1 : 2);
    if (dot != _activeDot) setState(() => _activeDot = dot);
  }

  Future<void> _openFavorites() async {
    final signedIn = await ensureSignedIn(
      context,
      reason: 'Entre para ver seus favoritos.',
    );
    if (!signedIn || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesPage()),
    );
  }

  void _openNotifications() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  void _openSearch() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void _showCategory(String slug) {
    context.read<ExploreController>().showCategory(slug);
    context.read<AppTabController>().goTo(AppTab.explore);
  }

  void _showEventType(String slug) {
    context.read<ExploreController>().showEventType(slug);
    context.read<AppTabController>().goTo(AppTab.explore);
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    final hasShortcuts =
        widget.categories.isNotEmpty || widget.eventTypes.isNotEmpty;
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.only(
        top: statusBarHeight + 16,
        bottom: AppSpacing.headerVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.headerBand,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            offset: const Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.headerHorizontalPadding,
            ),
            child: Row(
              children: [
                Expanded(child: _SearchBar(onTap: _openSearch)),
                const SizedBox(width: 12),
                _HeaderIconButton(
                  icon: Icons.favorite_border,
                  tooltip: 'Favoritos',
                  onPressed: _openFavorites,
                ),
                const SizedBox(width: 12),
                _HeaderIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Notificações',
                  onPressed: _openNotifications,
                ),
              ],
            ),
          ),
          if (hasShortcuts) ...[
            const SizedBox(height: 20),
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.headerHorizontalPadding,
              ),
              child: Row(
                spacing: AppSpacing.categorySpacing,
                children: [
                  for (final category in widget.categories)
                    _Shortcut(
                      label: category.name,
                      icon: iconForCategory(category.iconKey),
                      onTap: () => _showCategory(category.slug),
                    ),
                  for (final eventType in widget.eventTypes)
                    _Shortcut(
                      label: eventType.name,
                      icon: iconForEventType(eventType.slug),
                      onTap: () => _showEventType(eventType.slug),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Só indica que a lista rola para o lado: não é informação.
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [for (var i = 0; i < 3; i++) _dot(i)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(int index) {
    final isActive = index == _activeDot;
    final colors = context.colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 6 : 4,
      height: isActive ? 6 : 4,
      decoration: BoxDecoration(
        color: isActive
            ? colors.textPrimary
            : colors.textTertiary.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: 'Buscar salões, atrações e serviços',
      child: Material(
        color: colors.raisedSurface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search, color: colors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'O que vamos comemorar?',
                        style: context.text.headerSearch,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: context.colors.raisedSurface,
        foregroundColor: context.colors.primary,
        fixedSize: const Size(48, 48),
      ),
    );
  }
}

/// Atalho de categoria ou tipo de evento.
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver $label',
      child: Material(
        color: context.colors.raisedSurface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 90, minHeight: 64),
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 30, color: context.colors.primary),
                    const SizedBox(height: 6),
                    Text(label, style: context.text.categoryLabel, maxLines: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
