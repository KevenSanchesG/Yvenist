import 'package:flutter/material.dart';

/// Cores que **não** mudam com o tema: a marca e o que vai sobre fundos que
/// são sempre escuros (degradês, fotos escurecidas).
///
/// O resto (fundos, textos, bordas, cores de estado) muda entre o tema claro
/// e o escuro e fica em `AppPalette` (`app_palette.dart`), que as telas leem
/// por `context.colors`.
abstract final class AppColors {
  /// O laranja da marca, no tema claro: 5,2:1 com o branco, então serve como
  /// texto, como ícone e como fundo de botão com texto branco.
  static const Color brand = Color(0xFFC2410C);

  /// O mesmo matiz, mais claro: é o laranja do tema escuro e o de qualquer
  /// lugar que seja sempre escuro (a tela de convite ao fornecedor).
  static const Color brandOnDark = Color(0xFFFB8656);

  /// Degradês que recebem texto branco por cima, nos dois temas. As duas
  /// pontas de cada um têm pelo menos 4,5:1 com o branco, então o texto é
  /// legível em qualquer ponto.
  static const List<Color> clientGradient = [
    Color(0xFFA63A0B),
    Color(0xFFD0460D),
  ];
  static const List<Color> vendorGradient = [
    Color(0xFF2C3E50),
    Color(0xFF3A7D88),
  ];
  static const List<Color> successGradient = [
    Color(0xFF166534),
    Color(0xFF15803D),
  ];

  /// Texto e ícones sobre os degradês e sobre uma foto escurecida.
  static const Color onGradient = Color(0xFFFFFFFF);

  /// Película escura sobre uma foto de fundo, para o texto branco ser legível
  /// qualquer que seja a foto.
  static const Color photoScrim = Color(0xB3000000);
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
