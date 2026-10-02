import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_palette.dart';

/// Estilos de texto do app, já com a cor do tema em uso. As telas os leem por
/// `context.text` (`app_theme.dart`).
///
/// Nenhum estilo fica abaixo de 11sp: tamanhos menores (o protótipo usava 8 a
/// 10sp nos cards) não são legíveis para boa parte das pessoas.
class AppTypography {
  AppTypography._(AppPalette colors)
    : headerSearch = TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: colors.textTertiary,
      ),
      categoryLabel = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      sectionTitle = TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      sectionSubtitle = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      cardTitle = TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      cardPrice = TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: colors.onPrimary,
      ),
      cardRatingScore = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      cardRatingCount = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      cardLocation = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textTertiary,
      ),
      body = TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      caption = TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      );

  /// Os estilos para uma paleta. Os dos dois temas ficam guardados; durante a
  /// animação de troca de tema a paleta é uma mistura das duas, e os estilos
  /// são montados na hora para o texto mudar de cor junto com o fundo.
  factory AppTypography.forPalette(AppPalette colors) {
    if (identical(colors, AppPalette.light)) return _light;
    if (identical(colors, AppPalette.dark)) return _dark;
    return AppTypography._(colors);
  }

  /// Inter 4.1, embutida no app (`assets/fonts`, declarada no `pubspec.yaml`)
  /// nos pesos 400, 500, 600 e 700. Um peso fora dessa lista seria desenhado
  /// com o mais próximo dela.
  static const String fontFamily = 'Inter';

  /// Rótulo da barra de navegação. Sem cor: quem usa escolhe conforme a aba
  /// está ativa ou não.
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static final AppTypography _light = AppTypography._(AppPalette.light);
  static final AppTypography _dark = AppTypography._(AppPalette.dark);

  final TextStyle headerSearch;
  final TextStyle categoryLabel;
  final TextStyle sectionTitle;
  final TextStyle sectionSubtitle;
  final TextStyle cardTitle;

  /// Sobre o selo de preço, que tem o fundo no laranja da marca.
  final TextStyle cardPrice;
  final TextStyle cardRatingScore;
  final TextStyle cardRatingCount;
  final TextStyle cardLocation;
  final TextStyle body;
  final TextStyle caption;
}
