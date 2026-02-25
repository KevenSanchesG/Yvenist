import 'package:flutter/material.dart';
import 'app_colors.dart'; // Importa as cores que acabamos de criar

class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle headerSearch = TextStyle(
    fontFamily: fontFamily, fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.searchPlaceholder,
  );
  static const TextStyle categoryLabel = TextStyle(
    fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle sectionSubtitle = TextStyle(
    fontFamily: fontFamily, fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static const TextStyle cardTitle = TextStyle(
    fontFamily: fontFamily, fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle cardPrice = TextStyle(
    fontFamily: fontFamily, fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white,
  );
  static const TextStyle cardRatingScore = TextStyle(
    fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle cardRatingCount = TextStyle(
    fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static const TextStyle cardLocation = TextStyle(
    fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
  );
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily, fontSize: 10, fontWeight: FontWeight.w400,
  );
}