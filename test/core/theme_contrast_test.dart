import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_theme.dart';

/// Contraste entre duas cores opacas, pela fórmula da WCAG 2.x.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A cor que se vê quando [tint] (translúcida) fica por cima de [background].
Color over(Color tint, Color background) => Color.alphaBlend(tint, background);

/// Mínimo da WCAG AA para texto de tamanho normal.
const double aa = 4.5;

/// Mínimo da WCAG AA para o que não é texto e delimita ou indica o estado de
/// um controle: bordas, indicador de foco (critério 1.4.11).
const double nonText = 3;

/// Confere o contraste de cada combinação de texto e fundo que o app usa.
///
/// É um teste sobre as cores, e não sobre telas renderizadas, de propósito: a
/// verificação de contraste do Flutter (`textContrastGuideline`) mede a imagem
/// em baixa resolução e erra em letras pequenas e finas. Aqui a conta é exata.
void main() {
  const white = Colors.white;
  final screenGrey = Colors.grey.shade50; // fundo da aba Perfil

  void expectReadable(Color text, Color background, {String? reason}) {
    expect(
      contrast(text, background),
      greaterThanOrEqualTo(aa),
      reason: reason,
    );
  }

  test('a fórmula bate com os valores conhecidos', () {
    expect(contrast(Colors.black, white), closeTo(21, 0.01));
    expect(contrast(white, white), 1);
    // O valor que motivou a criação de primaryStrong.
    expect(contrast(AppColors.primary, white), closeTo(2.94, 0.01));
  });

  group('texto sobre fundos claros', () {
    test('texto principal e de apoio', () {
      for (final background in [
        white,
        screenGrey,
        AppColors.headerBackground,
      ]) {
        expectReadable(AppColors.textPrimary, background);
        expectReadable(AppColors.textSecondary, background);
      }
    });

    test('cinzas mais claros, só sobre branco', () {
      expectReadable(AppColors.textTertiary, white);
      expectReadable(AppColors.searchPlaceholder, white);
      expectReadable(AppColors.navIconInactive, white);
    });

    test('laranja de texto, links e rótulo da aba ativa', () {
      expectReadable(AppColors.primaryStrong, white);
      expectReadable(AppColors.primaryStrong, screenGrey);
    });

    test('cores de status usadas como texto', () {
      for (final color in [
        AppColors.success,
        AppColors.danger,
        AppColors.warning,
      ]) {
        expectReadable(color, white);
        expectReadable(color, screenGrey);
      }
    });

    test('mensagem de erro dos campos', () {
      expectReadable(AppTheme.light().colorScheme.error, white);
    });
  });

  group('texto sobre fundos tingidos', () {
    // Um aviso ou item selecionado tem o fundo na própria cor, bem clara, e o
    // título nessa cor; a explicação vem em texto de apoio. Cada linha é um
    // uso real: (onde, cor, o que fica por baixo do fundo tingido).
    final usages = <(String, Color, Color)>[
      ('modo cliente selecionado', AppColors.primaryStrong, white),
      ('modo fornecedor selecionado', AppColors.vendor, white),
      ('selo de orçamento solicitado', AppColors.primaryStrong, white),
      ('erro de formulário', AppColors.danger, white),
      ('aviso de análise em andamento', AppColors.warning, screenGrey),
      ('aviso de cadastro recusado', AppColors.danger, screenGrey),
    ];

    for (final (where, color, base) in usages) {
      test(where, () {
        final background = over(AppColors.tint(color), base);

        expectReadable(color, background, reason: 'título na cor do destaque');
        expectReadable(AppColors.textSecondary, background);
        expectReadable(AppColors.textPrimary, background);
      });
    }
  });

  group('componentes do Material', () {
    final scheme = AppTheme.light().colorScheme;

    test('superfícies neutras: nada de cartão, menu ou calendário rosado', () {
      // Regressão: o Material 3 tinge as superfícies com a cor da marca. Com
      // o laranja elas saíam rosadas e destoavam do branco do resto do app.
      for (final surface in [
        scheme.surface,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
      ]) {
        expect(surface, white);
      }
      expect(scheme.surfaceTint.a, 0);
    });

    test('os controles usam o laranja dos botões', () {
      expect(scheme.primary, AppColors.primaryStrong);
      expectReadable(scheme.onPrimary, scheme.primary);
    });

    test('o texto que os componentes desenham sozinhos é legível', () {
      for (final surface in [
        scheme.surface,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ]) {
        expectReadable(scheme.onSurface, surface);
        expectReadable(scheme.onSurfaceVariant, surface);
      }
    });

    test('o texto dos componentes usa as cores de texto do app', () {
      // Regressão: rótulo de campo, de filtro e os números do calendário
      // saíam em um marrom derivado do laranja, ao lado do cinza do texto que
      // as telas escrevem.
      expect(scheme.onSurface, AppColors.textPrimary);
      expect(scheme.onSurfaceVariant, AppColors.textSecondary);
    });

    test('item selecionado: o destaque do app, e não um rosado', () {
      // Regressão: o segmento escolhido de um botão segmentado e o filtro
      // marcado saíam com o rosado que o Material deriva do laranja, diferente
      // do item selecionado do resto do app (o seletor de modo do perfil).
      final highlight = over(AppColors.tint(AppColors.primaryStrong), white);

      for (final (container, content) in [
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
        (scheme.primaryContainer, scheme.onPrimaryContainer),
      ]) {
        expect(container, highlight);
        expect(content, AppColors.primaryStrong);
        expectReadable(content, container);
      }
    });

    test('contornos neutros, e visíveis onde delimitam um controle', () {
      // Regressão: a borda dos filtros saía rosada e a do botão segmentado,
      // marrom, ao lado das bordas cinza dos cartões e dos campos.
      expect(scheme.outlineVariant, AppColors.divider);
      expect(scheme.outline, AppColors.textTertiary);
      expect(contrast(scheme.outline, white), greaterThanOrEqualTo(nonText));
    });

    test('campo em foco: a borda no mesmo laranja do rótulo e do cursor', () {
      // Regressão: a borda do campo em foco ficava no laranja da marca e o
      // rótulo e o cursor, no dos controles: dois laranjas no mesmo campo, e o
      // indicador de foco abaixo de 3:1.
      final focused = AppTheme.light().inputDecorationTheme.focusedBorder!;

      expect(focused.borderSide.color, scheme.primary);
      expect(
        contrast(focused.borderSide.color, white),
        greaterThanOrEqualTo(nonText),
      );
    });

    test('aviso (SnackBar): fundo neutro, texto e ação legíveis', () {
      // Regressão: o aviso saía em um marrom escuro com texto rosado.
      expect(scheme.inverseSurface, AppColors.textPrimary);
      expectReadable(scheme.onInverseSurface, scheme.inverseSurface);
      expectReadable(scheme.inversePrimary, scheme.inverseSurface);
    });
  });

  group('texto branco sobre cor', () {
    test('botões e selo de preço', () {
      expectReadable(white, AppColors.primaryStrong);
    });

    test('degradês: legível nas duas pontas, logo em todo o caminho', () {
      for (final gradient in [
        AppColors.clientGradient,
        AppColors.vendorGradient,
        AppColors.successGradient,
      ]) {
        for (final color in gradient) {
          expectReadable(white, color, reason: 'ponta $color');
        }
      }
    });
  });
}
