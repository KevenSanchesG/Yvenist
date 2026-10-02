import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';

/// As cores do app que mudam com o tema (claro ou escuro).
///
/// Uma tela nunca escreve uma cor à mão: pega daqui, por `context.colors`
/// (`app_theme.dart`). O contraste de cada combinação de texto e fundo, nos
/// dois temas, é conferido em `test/core/theme_contrast_test.dart` (mínimo de
/// 4,5:1, WCAG AA). Ao mudar uma cor, rode esse teste.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.inversePrimary,
    required this.background,
    required this.backgroundMuted,
    required this.surface,
    required this.surfaceMuted,
    required this.divider,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.danger,
    required this.warning,
    required this.vendor,
    required this.shadow,
    required this.tintOpacity,
  });

  /// Tema claro: fundo branco, texto em cinza escuro e o laranja da marca.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    primary: AppColors.brand,
    onPrimary: Color(0xFFFFFFFF),
    inversePrimary: AppColors.brandOnDark,
    background: Color(0xFFFFFFFF),
    backgroundMuted: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F3F4),
    divider: Color(0xFFE5E7EB),
    outline: Color(0xFF6B7280),
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF4B5563),
    textTertiary: Color(0xFF6B7280),
    success: Color(0xFF15803D),
    danger: Color(0xFFB91C1C),
    warning: Color(0xFF92400E),
    vendor: Color(0xFF2C3E50),
    shadow: Color(0x1A000000),
    tintOpacity: 0.08,
  );

  /// Tema escuro. Fundo cinza muito escuro, e não preto puro: texto claro
  /// sobre preto cansa a vista e "vibra". As superfícies ficam um tom acima
  /// do fundo, no lugar da sombra, que no escuro não se vê. As cores de
  /// destaque são versões mais claras das do tema claro, para manter o
  /// contraste.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    primary: AppColors.brandOnDark,
    onPrimary: Color(0xFF2A1206),
    inversePrimary: AppColors.brand,
    background: Color(0xFF121416),
    backgroundMuted: Color(0xFF0C0D0F),
    surface: Color(0xFF1C1F23),
    surfaceMuted: Color(0xFF272B30),
    divider: Color(0xFF343A41),
    outline: Color(0xFF8B93A1),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFC9CED6),
    textTertiary: Color(0xFF9BA3AF),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    vendor: Color(0xFF8EC7D2),
    shadow: Color(0x66000000),
    tintOpacity: 0.16,
  );

  final Brightness brightness;

  /// O laranja da marca: a cor de ação. Serve como texto, ícone e fundo de
  /// botão. Um tom só por tema.
  final Color primary;

  /// O que vai por cima de um fundo [primary] (o texto de um botão).
  final Color onPrimary;

  /// O laranja do outro tema: a ação dentro de um aviso (SnackBar), cujo
  /// fundo tem as cores invertidas.
  final Color inversePrimary;

  /// Fundo das telas.
  final Color background;

  /// Fundo das telas feitas de cartões (perfil, fila de análise): um tom
  /// abaixo do cartão, para ele se destacar sem borda.
  final Color backgroundMuted;

  /// Cartões, campos, folhas, diálogos e barras.
  final Color surface;

  /// Faixas e avisos neutros.
  final Color surfaceMuted;

  /// Linhas e bordas decorativas (cartões, campos).
  final Color divider;

  /// Contorno que delimita um controle: tem 3:1 com o fundo.
  final Color outline;

  final Color textPrimary;

  /// Texto de apoio. Legível também sobre [surfaceMuted] e sobre os fundos
  /// tingidos.
  final Color textSecondary;

  /// Texto e ícones discretos. Só sobre [background] e [surface].
  final Color textTertiary;

  /// Cores de estado. Servem como cor de texto.
  final Color success;
  final Color danger;
  final Color warning;

  /// Cor do modo fornecedor, como texto e destaque.
  final Color vendor;

  final Color shadow;

  /// Quanto de uma cor entra no fundo de um destaque ([tint]).
  final double tintOpacity;

  bool get isDark => brightness == Brightness.dark;

  /// Fundo suave de um elemento destacado com [color] (seleção, aviso, erro).
  /// O texto na própria [color] mantém o contraste sobre ele.
  Color tint(Color color) => color.withValues(alpha: tintOpacity);

  /// O mesmo destaque, já misturado com a [surface]: opaco, para os lugares
  /// que não aceitam transparência.
  Color get selectedSurface => Color.alphaBlend(tint(primary), surface);

  /// A faixa do topo da tela inicial. No tema claro é cinza, com controles
  /// brancos por cima; no escuro, o que se destaca é sempre o mais claro,
  /// então a faixa fica na cor dos cartões.
  Color get headerBand => isDark ? surface : surfaceMuted;

  /// Um controle que fica por cima de uma faixa, de um cartão ou de uma foto
  /// (a busca e os atalhos da tela inicial, os botões redondos dos anúncios):
  /// branco no tema claro, um tom acima do cartão no escuro.
  Color get raisedSurface => isDark ? surfaceMuted : surface;

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? inversePrimary,
    Color? background,
    Color? backgroundMuted,
    Color? surface,
    Color? surfaceMuted,
    Color? divider,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? danger,
    Color? warning,
    Color? vendor,
    Color? shadow,
    double? tintOpacity,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      inversePrimary: inversePrimary ?? this.inversePrimary,
      background: background ?? this.background,
      backgroundMuted: backgroundMuted ?? this.backgroundMuted,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      divider: divider ?? this.divider,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      vendor: vendor ?? this.vendor,
      shadow: shadow ?? this.shadow,
      tintOpacity: tintOpacity ?? this.tintOpacity,
    );
  }

  /// Usado pelo Flutter para animar a troca de tema: as cores passam de uma
  /// paleta para a outra aos poucos, em vez de trocar de uma vez.
  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      inversePrimary: mix(inversePrimary, other.inversePrimary),
      background: mix(background, other.background),
      backgroundMuted: mix(backgroundMuted, other.backgroundMuted),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      divider: mix(divider, other.divider),
      outline: mix(outline, other.outline),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      success: mix(success, other.success),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      vendor: mix(vendor, other.vendor),
      shadow: mix(shadow, other.shadow),
      tintOpacity: tintOpacity + (other.tintOpacity - tintOpacity) * t,
    );
  }
}
