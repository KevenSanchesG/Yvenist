import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 65,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. A Barra Branca
          Container(
            height: 65,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.bottomNavBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _NavItem(
                    icon: Icons.home,
                    label: 'Início',
                    isSelected: selectedIndex == 0,
                    onTap: () => onTabChange(0),
                  ),
                  _NavItem(
                    icon: Icons.explore_outlined,
                    label: 'Explorar',
                    isSelected: selectedIndex == 1,
                    onTap: () => onTabChange(1),
                  ),

                  // Espaço Central para o Bolo
                  const SizedBox(width: 48),

                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Chat',
                    isSelected: selectedIndex == 3,
                    onTap: () => onTabChange(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    isSelected: selectedIndex == 4,
                    onTap: () => onTabChange(4),
                  ),
                ],
              ),
            ),
          ),

          // 2. O Botão Flutuante (Bolo - Índice 2)
          Positioned(
            bottom: 20,
            child: GestureDetector(
              onTap: () => onTabChange(2),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary, // Bolo sempre laranja
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(Icons.cake, color: Colors.white, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Container com altura fixa igual à barra para garantir alinhamento no topo
      child: SizedBox(
        height: 65, 
        width: 50, // Largura fixa para centralizar a linha
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- A LINHA SUPERIOR ---
            Positioned(
              top: 0, // Cola no topo da barra branca
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3, // Espessura da linha
                width: isSelected ? 30 : 0, // Se selecionado, largura 30. Se não, 0 (some)
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),

            // --- ÍCONE E TEXTO ---
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 30,
                  color: isSelected ? AppColors.primary : AppColors.navIconInactive,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTypography.navLabel.copyWith(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.navIconInactive,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}