import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

// --- BOTÃO DE ÍCONE DO CABEÇALHO ---
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const HeaderIconButton({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppColors.iconBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 24, color: AppColors.primary),
      ),
    );
  }
}

// --- ITEM DE CATEGORIA ---
class CategoryItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;

  const CategoryItem({
    super.key,
    required this.label,
    required this.icon,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90, 
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: AppColors.categoryBackground,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: AppColors.primary),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: AppTypography.categoryLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}