import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Laranja da marca: ícones, botões e áreas grandes.
  static const Color primary = Color(0xFFFF6600);

  /// Laranja escurecido para **texto pequeno** sobre branco e para fundo de
  /// texto branco. O laranja da marca tem contraste de 2,9:1 com o branco,
  /// abaixo do mínimo de 4,5:1 da WCAG AA; este tem 5,2:1.
  static const Color primaryStrong = Color(0xFFC2410C);

  /// Cor do modo fornecedor.
  static const Color vendor = Color(0xFF2C3E50);
  static const Color vendorAccent = Color(0xFF4CA1AF);

  static const Color headerBackground = Color(0xFFF2F3F4);
  static const Color searchFieldBackground = Color(0xFFFFFFFF);
  static const Color searchPlaceholder = Color(0xFF6B7280);
  static const Color iconBackground = Color(0xFFFFFFFF);
  static const Color categoryBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color cardShadow = Color(0x1A000000);
  static const Color cardActionBackground = Color(0xCCF2F3F4);
  static const Color cardActionIconInactive = Color(0xFF545454);
  static const Color bottomNavBackground = Color(0xFFFFFFFF);
  static const Color navIconInactive = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF15803D);
  static const Color danger = Color(0xFFB91C1C);
  static const Color warning = Color(0xFFB45309);
}

abstract final class AppSpacing {
  static const double screenMargin = 16.0;
  static const double headerHorizontalPadding = 22.0;
  static const double headerVerticalPadding = 14.0;
  static const double sectionHorizontalPadding = 24.0;
  static const double cardSpacing = 16.0;
  static const double categorySpacing = 16.0;

  /// Menor área de toque recomendada (Material e WCAG 2.5.5).
  static const double minTouchTarget = 48.0;
}
