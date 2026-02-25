import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';


class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Nota: Certifique-se que AppSpacing está importado corretamente
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.sectionTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: AppTypography.sectionSubtitle),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.primary, size: 24),
        ],
      ),
    );
  }
}