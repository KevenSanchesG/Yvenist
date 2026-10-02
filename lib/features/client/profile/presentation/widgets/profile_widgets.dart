import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// Item de lista das telas de conta (segurança, dados...).
///
/// Sem [onTap] o item aparece como "Em breve": fica visível que a função está
/// prevista, mas não parece clicável.
class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isAvailable = onTap != null;
    final color = !isAvailable
        ? AppColors.textSecondary
        : (isDestructive ? AppColors.danger : AppColors.primary);
    final supportingText = subtitle ?? (isAvailable ? null : 'Em breve');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.tint(color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isDestructive && isAvailable
                ? AppColors.danger
                : AppColors.textPrimary,
          ),
        ),
        subtitle: supportingText == null ? null : Text(supportingText),
        trailing: isAvailable
            ? const Icon(Icons.chevron_right, color: AppColors.textSecondary)
            : null,
      ),
    );
  }
}

/// Título de um grupo de opções.
class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
