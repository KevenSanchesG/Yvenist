import 'package:flutter/material.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// Barra de navegação inferior, com o botão do Party Maker em destaque.
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  static const double _barHeight = 65;

  @override
  Widget build(BuildContext context) {
    // Respeita a área de gestos/botões do sistema na parte de baixo da tela.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      // Material (e não um Container colorido) para o efeito de toque dos
      // itens aparecer por cima do fundo.
      child: Material(
        color: AppColors.bottomNavBackground,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(height: _barHeight, child: _buildItems()),
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavItem(
                icon: Icons.home,
                label: 'Início',
                isSelected: current == AppTab.home,
                onTap: () => onSelected(AppTab.home),
              ),
              _NavItem(
                icon: Icons.explore_outlined,
                label: 'Explorar',
                isSelected: current == AppTab.explore,
                onTap: () => onSelected(AppTab.explore),
              ),
              // Espaço do botão central.
              const SizedBox(width: 64),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                isSelected: current == AppTab.chat,
                onTap: () => onSelected(AppTab.chat),
              ),
              _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                isSelected: current == AppTab.profile,
                onTap: () => onSelected(AppTab.profile),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          child: Semantics(
            button: true,
            selected: current == AppTab.partyMaker,
            label: 'Minhas festas',
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 4),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(AppTab.partyMaker),
                child: const SizedBox(
                  width: 64,
                  height: 64,
                  child: ExcludeSemantics(
                    child: Icon(Icons.cake, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // O ícone pode usar o laranja da marca (contraste de 3:1 basta para
    // elementos gráficos); o texto pequeno usa a versão escurecida.
    final iconColor = isSelected
        ? AppColors.primary
        : AppColors.navIconInactive;
    final labelColor = isSelected
        ? AppColors.primaryStrong
        : AppColors.navIconInactive;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: SizedBox(
          width: 64,
          height: AppBottomNavBar._barHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 3,
                  width: isSelected ? 30 : 0,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 28, color: iconColor),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.navLabel.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
