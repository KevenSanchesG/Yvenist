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
