import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_palette.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// O caminho das telas até as cores e os estilos de texto do tema em uso.
extension AppThemeContext on BuildContext {
  /// As cores do tema em uso (claro ou escuro).
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;

  /// Os estilos de texto, com as cores do tema em uso.
  AppTypography get text => AppTypography.forPalette(colors);
}

/// Os dois temas do app. Cada tela herda daqui em vez de repetir cores e
/// bordas.
abstract final class AppTheme {
  static final ThemeData _light = _build(AppPalette.light);
  static final ThemeData _dark = _build(AppPalette.dark);

  static ThemeData light() => _light;
  static ThemeData dark() => _dark;

  /// Barra de status e de navegação do sistema para uma tela comum: ícones
  /// escuros no tema claro, claros no escuro.
  static SystemUiOverlayStyle systemUi(AppPalette colors) {
    final icons = colors.isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: icons, // Android
      statusBarBrightness: colors.brightness, // iOS
      systemNavigationBarColor: colors.surface,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: icons,
    );
  }

  /// Para telas cujo topo é escuro nos dois temas (o cabeçalho do perfil):
  /// relógio e ícones da barra de status em branco.
  static SystemUiOverlayStyle systemUiOnDarkHeader(AppPalette colors) {
    return systemUi(colors).copyWith(
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
    );
  }

  static ThemeData _build(AppPalette colors) {
    final text = AppTypography.forPalette(colors);

    // O Material 3 deriva da cor da marca todas as cores que os componentes
    // usam sozinhos, e o resultado destoa do resto do app (marrons e rosados
    // no tema claro). Cada papel abaixo troca a cor derivada por uma da
    // paleta do app.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: colors.brightness,
        ).copyWith(
          // Controles: caixa de seleção, opção marcada, dia escolhido no
          // calendário, rótulo e cursor do campo em foco.
          primary: colors.primary,
          onPrimary: colors.onPrimary,
          // Item selecionado (segmento de um botão segmentado, filtro
          // marcado): o mesmo destaque do seletor de modo do perfil.
          primaryContainer: colors.selectedSurface,
          onPrimaryContainer: colors.primary,
          secondaryContainer: colors.selectedSurface,
          onSecondaryContainer: colors.primary,
          // Cartões, menus, listas suspensas, calendário.
          surface: colors.surface,
          surfaceContainerLowest: colors.surface,
          surfaceContainerLow: colors.surface,
          surfaceContainer: colors.surface,
          surfaceContainerHigh: colors.surfaceMuted,
          surfaceContainerHighest: colors.divider,
          surfaceTint: Colors.transparent,
          // Texto que os componentes escrevem: rótulo de campo e de filtro,
          // itens de menu, calendário.
          onSurface: colors.textPrimary,
          onSurfaceVariant: colors.textSecondary,
          // Contornos: o de um controle precisa de 3:1 com o fundo; o
          // decorativo é o mesmo dos cartões e dos campos.
          outline: colors.outline,
          outlineVariant: colors.divider,
          // Aviso (SnackBar): as cores do texto e do fundo, invertidas.
          inverseSurface: colors.textPrimary,
          onInverseSurface: colors.background,
          inversePrimary: colors.inversePrimary,
          error: colors.danger,
        );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.divider),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [colors],
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.sectionTitle,
        iconTheme: IconThemeData(color: colors.primary),
        systemOverlayStyle: systemUi(colors),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        // O mesmo laranja do rótulo e do cursor do campo em foco, que vêm de
        // `scheme.primary`.
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      // Diálogos, calendário, folhas e menus na cor dos cartões (o padrão do
      // Material 3 para diálogos é um tom acima da superfície).
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.sectionTitle,
        contentTextStyle: text.body,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: colors.textTertiary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colors.primary,
        unselectedLabelColor: colors.textSecondary,
        indicatorColor: colors.primary,
        dividerColor: colors.divider,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
      dividerTheme: DividerThemeData(color: colors.divider),
    );
  }
}
