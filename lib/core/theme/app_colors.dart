import 'package:flutter/material.dart';

/// Cores do app.
///
/// As combinações de texto e fundo usadas nas telas têm o contraste conferido
/// em `test/core/theme_contrast_test.dart` (mínimo de 4,5:1, WCAG AA). Ao
/// mudar uma cor, rode esse teste.
abstract final class AppColors {
  /// Laranja da marca: ícones e áreas grandes.
  ///
  /// Sobre branco tem contraste de 2,9:1. Não serve para texto (mínimo de
  /// 4,5:1) e fica no limite dos 3:1 pedidos para ícones; para texto e para
  /// fundo de texto branco use [primaryStrong].
  static const Color primary = Color(0xFFFF6600);

  /// Laranja escurecido para **texto pequeno** sobre branco e para fundo de
  /// texto branco: 5,2:1 com o branco.
  static const Color primaryStrong = Color(0xFFC2410C);

  /// Cores do modo fornecedor.
  static const Color vendor = Color(0xFF2C3E50);
  static const Color vendorAccent = Color(0xFF3A7D88);

  /// Degradês que recebem texto branco por cima. As duas pontas de cada um têm
  /// pelo menos 4,5:1 com o branco, então o texto é legível em qualquer ponto
  /// (terminar no laranja da marca deixava o e-mail do perfil com 3,7:1).
  static const List<Color> clientGradient = [
    Color(0xFFA63A0B),
    Color(0xFFD0460D),
  ];
  static const List<Color> vendorGradient = [vendor, vendorAccent];
  static const List<Color> successGradient = [Color(0xFF166534), success];

  static const Color headerBackground = Color(0xFFF2F3F4);
  static const Color searchFieldBackground = Color(0xFFFFFFFF);
  static const Color iconBackground = Color(0xFFFFFFFF);
  static const Color categoryBackground = Color(0xFFFFFFFF);
  static const Color bottomNavBackground = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF333333);

  /// Texto de apoio. Escuro o bastante para continuar legível também sobre os
  /// fundos levemente coloridos (cabeçalho cinza, avisos).
  static const Color textSecondary = Color(0xFF4B5563);

  /// Cinzas mais claros, usados **só sobre branco** (4,8:1).
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color searchPlaceholder = Color(0xFF6B7280);
  static const Color navIconInactive = Color(0xFF6B7280);

  static const Color cardShadow = Color(0x1A000000);
  static const Color divider = Color(0xFFE5E7EB);

  static const Color success = Color(0xFF15803D);
  static const Color danger = Color(0xFFB91C1C);
  static const Color warning = Color(0xFF92400E);

  /// Fundo suave de um elemento destacado com [color] (seleção, aviso, erro).
  /// O texto na própria [color] mantém o contraste sobre ele.
  static Color tint(Color color) => color.withValues(alpha: 0.08);
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

  /// Quanto o botão central da navegação sobe acima da barra inferior. Um
  /// rodapé fixo em uma aba precisa deixar essa folga para não ficar por baixo
  /// do botão.
  static const double navButtonOverlap = 19.0;
}
