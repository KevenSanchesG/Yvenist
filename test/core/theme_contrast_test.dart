import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_palette.dart';
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

void expectReadable(Color text, Color background, {String? reason}) {
  expect(contrast(text, background), greaterThanOrEqualTo(aa), reason: reason);
}

/// Confere o contraste de cada combinação de texto e fundo que o app usa, nos
/// dois temas.
///
/// É um teste sobre as cores, e não sobre telas renderizadas, de propósito: a
/// verificação de contraste do Flutter (`textContrastGuideline`) mede a imagem
/// em baixa resolução e erra em letras pequenas e finas. Aqui a conta é exata.
void main() {
  const white = Color(0xFFFFFFFF);

  test('a fórmula bate com os valores conhecidos', () {
    expect(contrast(Colors.black, white), closeTo(21, 0.01));
    expect(contrast(white, white), 1);
    // O laranja antigo da marca (#FF6600), que não servia para texto, e o que
    // os donos escolheram como tom único.
    expect(contrast(const Color(0xFFFF6600), white), closeTo(2.94, 0.01));
    expect(contrast(AppColors.brand, white), closeTo(5.18, 0.01));
  });

  test('o laranja da marca é um só em cada tema', () {
    expect(AppPalette.light.primary, AppColors.brand);
    expect(AppPalette.dark.primary, AppColors.brandOnDark);
  });

  for (final (name, colors, theme) in [
    ('tema claro', AppPalette.light, AppTheme.light()),
    ('tema escuro', AppPalette.dark, AppTheme.dark()),
  ]) {
    group(name, () {
      final scheme = theme.colorScheme;

      test('o tema carrega a paleta e o brilho certos', () {
        expect(theme.extension<AppPalette>(), same(colors));
        expect(theme.brightness, colors.brightness);
        expect(theme.scaffoldBackgroundColor, colors.background);
      });

      group('texto sobre os fundos', () {
        test('texto principal e de apoio, em qualquer fundo', () {
          for (final background in [
            colors.background,
            colors.backgroundMuted,
            colors.surface,
            colors.surfaceMuted,
            colors.headerBand,
            colors.raisedSurface,
          ]) {
            expectReadable(colors.textPrimary, background);
            expectReadable(colors.textSecondary, background);
          }
        });

        test('texto discreto, onde ele é usado', () {
          // Só sobre o fundo das telas, os cartões e os controles da faixa do
          // topo: no tema claro ele não passa sobre a faixa cinza.
          for (final background in [
            colors.background,
            colors.backgroundMuted,
            colors.surface,
            colors.raisedSurface,
          ]) {
            expectReadable(colors.textTertiary, background);
          }
        });

        test('laranja como texto, link, ícone e rótulo da aba ativa', () {
          for (final background in [
            colors.background,
            colors.backgroundMuted,
            colors.surface,
            colors.surfaceMuted,
            colors.raisedSurface,
          ]) {
            expectReadable(colors.primary, background);
          }
        });

        test('cores de estado usadas como texto', () {
          for (final color in [colors.success, colors.danger, colors.warning]) {
            for (final background in [
              colors.background,
              colors.backgroundMuted,
              colors.surface,
            ]) {
              expectReadable(color, background);
            }
          }
        });

        test('cor do modo fornecedor', () {
          expectReadable(colors.vendor, colors.surface);
        });

        test('sugestão de parceiros na festa: o botão de adicionar', () {
          // O ícone laranja é o que se toca, sobre a faixa neutra.
          expect(
            contrast(colors.primary, colors.surfaceMuted),
            greaterThanOrEqualTo(nonText),
          );
        });
      });

      group('texto sobre fundos tingidos', () {
        // Um aviso ou item selecionado tem o fundo na própria cor, bem suave,
        // e o título nessa cor; a explicação vem em texto de apoio. Cada linha
        // é um uso real: (onde, cor, o que fica por baixo do fundo tingido).
        final usages = <(String, Color, Color)>[
          ('modo cliente selecionado', colors.primary, colors.surface),
          ('modo fornecedor selecionado', colors.vendor, colors.surface),
          ('selo de orçamento solicitado', colors.primary, colors.background),
          ('erro de formulário', colors.danger, colors.background),
          ('erro de formulário em um diálogo', colors.danger, colors.surface),
          (
            'aviso de análise em andamento',
            colors.warning,
            colors.backgroundMuted,
          ),
          ('aviso de cadastro recusado', colors.danger, colors.backgroundMuted),
          ('ícone de um item de configuração', colors.primary, colors.surface),
          ('ícone de uma ação destrutiva', colors.danger, colors.surface),
          // A faixa que diz em que pé a festa está: uma cor por situação.
          ('festa em planejamento', colors.textSecondary, colors.background),
          (
            'festa com o orçamento solicitado',
            colors.primary,
            colors.background,
          ),
          ('festa com a edição solicitada', colors.warning, colors.background),
          ('festa com o orçamento recebido', colors.success, colors.background),
          ('festa cancelada', colors.danger, colors.background),
          (
            'o que falta para pedir o orçamento',
            colors.warning,
            colors.background,
          ),
        ];

        for (final (where, color, base) in usages) {
          test(where, () {
            final background = over(colors.tint(color), base);

            expectReadable(
              color,
              background,
              reason: 'título na cor do destaque',
            );
            expectReadable(colors.textSecondary, background);
            expectReadable(colors.textPrimary, background);
          });
        }
      });

      group('componentes do Material', () {
        test('superfícies na cor dos cartões, sem a tinta da marca', () {
          // Regressão: o Material 3 tinge as superfícies com a cor da marca.
          // Com o laranja elas saíam rosadas no tema claro e destoavam do
          // resto do app.
          for (final surface in [
            scheme.surface,
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
            scheme.surfaceContainer,
          ]) {
            expect(surface, colors.surface);
          }
          expect(scheme.surfaceTint.a, 0);
        });

        test('os controles usam o laranja dos botões', () {
          expect(scheme.primary, colors.primary);
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
          // saíam em um marrom derivado do laranja, ao lado do cinza do texto
          // que as telas escrevem.
          expect(scheme.onSurface, colors.textPrimary);
          expect(scheme.onSurfaceVariant, colors.textSecondary);
        });

        test('item selecionado: o destaque do app, e não um rosado', () {
          // Regressão: o segmento escolhido de um botão segmentado e o filtro
          // marcado saíam com o rosado que o Material deriva do laranja,
          // diferente do item selecionado do resto do app (o seletor de modo
          // do perfil).
          final highlight = over(colors.tint(colors.primary), colors.surface);

          for (final (container, content) in [
            (scheme.secondaryContainer, scheme.onSecondaryContainer),
            (scheme.primaryContainer, scheme.onPrimaryContainer),
          ]) {
            expect(container, highlight);
            expect(content, colors.primary);
            expectReadable(content, container);
          }
        });

        test('contornos neutros, e visíveis onde delimitam um controle', () {
          // Regressão: a borda dos filtros saía rosada e a do botão
          // segmentado, marrom, ao lado das bordas cinza dos cartões e dos
          // campos.
          expect(scheme.outlineVariant, colors.divider);
          expect(scheme.outline, colors.outline);
          for (final background in [colors.surface, colors.background]) {
            expect(
              contrast(scheme.outline, background),
              greaterThanOrEqualTo(nonText),
            );
          }
        });

        test('campo em foco: a borda no mesmo laranja do rótulo e do '
            'cursor', () {
          // Regressão: a borda do campo em foco ficava em um laranja e o
          // rótulo e o cursor, em outro: dois laranjas no mesmo campo, e o
          // indicador de foco abaixo de 3:1.
          final focused = theme.inputDecorationTheme.focusedBorder!;

          expect(focused.borderSide.color, scheme.primary);
          expect(
            contrast(focused.borderSide.color, colors.surface),
            greaterThanOrEqualTo(nonText),
          );
        });

        test('aviso (SnackBar): fundo neutro, texto e ação legíveis', () {
          // Regressão: no tema claro o aviso saía em um marrom escuro com
          // texto rosado.
          expect(scheme.inverseSurface, colors.textPrimary);
          expectReadable(scheme.onInverseSurface, scheme.inverseSurface);
          expectReadable(scheme.inversePrimary, scheme.inverseSurface);
        });

        test('mensagem de erro dos campos', () {
          expect(scheme.error, colors.danger);
          expectReadable(scheme.error, colors.surface);
          expectReadable(scheme.error, colors.background);
        });
      });

      group('o que vai sobre o laranja', () {
        test('texto de botão e selo de preço', () {
          expectReadable(colors.onPrimary, colors.primary);
        });

        test('um botão se destaca do fundo', () {
          for (final background in [colors.background, colors.surface]) {
            expect(
              contrast(colors.primary, background),
              greaterThanOrEqualTo(nonText),
            );
          }
        });
      });
    });
  }

  group('fundos que são escuros nos dois temas', () {
    test('degradês: texto branco legível nas duas pontas, logo em todo o '
        'caminho', () {
      for (final gradient in [
        AppColors.clientGradient,
        AppColors.vendorGradient,
        AppColors.successGradient,
      ]) {
        for (final color in gradient) {
          expectReadable(AppColors.onGradient, color, reason: 'ponta $color');
        }
      }
    });

    test('convite ao fornecedor: texto e ícones sobre a foto escurecida', () {
      // O que fica por baixo da película escura varia. O pior caso para o
      // texto branco é o mais claro possível (uma foto toda branca, ou o
      // substituto claro da imagem que não carregou); o outro extremo é a cor
      // de fundo da tela.
      for (final photo in [white, AppColors.vendorGradient.first]) {
        final background = over(AppColors.photoScrim, photo);

        expectReadable(AppColors.onGradient, background);
        // Os ícones laranja são decorativos: vale o mínimo do que não é
        // texto.
        expect(
          contrast(AppColors.brandOnDark, background),
          greaterThanOrEqualTo(nonText),
        );
      }
    });
  });

  test('a troca de tema mistura as duas paletas aos poucos', () {
    final half = AppPalette.light.lerp(AppPalette.dark, 0.5);

    expect(AppPalette.light.lerp(AppPalette.dark, 0), isA<AppPalette>());
    expect(
      half.background,
      Color.lerp(AppPalette.light.background, AppPalette.dark.background, 0.5),
    );
    expect(
      AppPalette.light.lerp(AppPalette.dark, 1).primary,
      AppColors.brandOnDark,
    );
    expect(AppPalette.light.lerp(null, 0.5), same(AppPalette.light));
  });
}
