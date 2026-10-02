import 'package:flutter/material.dart';
import 'package:yvenist/core/navigation/app_tab_controller.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// Barra de navegação inferior: quatro abas e, no centro, o espaço do botão do
/// Party Maker ([PartyTabButton]).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.current,
    required this.onSelected,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelected;

  static const double barHeight = 65;

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
          child: SizedBox(
            height: barHeight,
            child: Padding(
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
                  const SizedBox(width: PartyTabButton.size),
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
          ),
        ),
      ),
    );
  }
}

/// Botão redondo do Party Maker, em destaque no centro da barra.
///
/// Fica no espaço de "botão flutuante" do Scaffold, e não dentro da barra: a
/// parte de cima dele sai dos limites da barra, e o que é desenhado fora dos
/// limites de um widget não recebe toques.
class PartyTabButton extends StatelessWidget {
  const PartyTabButton({
    super.key,
    required this.isSelected,
    required this.onPressed,
  });

  final bool isSelected;
  final VoidCallback onPressed;

  static const double size = 64;
  static const double _ringWidth = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Minhas festas',
      // Um círculo branco com o círculo colorido dentro. (Uma borda branca
      // desenhada por cima do círculo deixava um fio laranja na beirada.)
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(_ringWidth),
          child: Material(
            // Mais escuro com a aba aberta: é o "você está aqui" deste botão,
            // que não tem o traço das outras abas.
            color: isSelected ? AppColors.primaryStrong : AppColors.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: const SizedBox(
                width: size - 2 * _ringWidth,
                height: size - 2 * _ringWidth,
                child: ExcludeSemantics(
                  child: Icon(Icons.cake, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Posição do [PartyTabButton]: centralizado, encaixado no topo da barra.
class PartyTabButtonLocation extends FloatingActionButtonLocation {
  const PartyTabButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final buttonWidth = scaffoldGeometry.floatingActionButtonSize.width;
    return Offset(
      (scaffoldGeometry.scaffoldSize.width - buttonWidth) / 2,
      // `contentBottom` é onde o conteúdo termina e a barra começa.
      scaffoldGeometry.contentBottom - AppSpacing.navButtonOverlap,
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
    // O ícone ativo usa o laranja da marca; o texto pequeno, a versão
    // escurecida, que tem contraste suficiente.
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
          height: AppBottomNavBar.barHeight,
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
