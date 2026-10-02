import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// As telas pegam as cores do tema em uso (`context.colors`), e não de uma cor
/// escrita à mão.
///
/// Uma cor fixa vale para um tema só: um texto cinza escuro escrito à mão some
/// no tema escuro, e nenhum teste de contraste a enxerga, porque eles conferem
/// as cores da paleta.
void main() {
  // `Colors.transparent` não é uma cor de tema: é a ausência de cor.
  final handWritten = RegExp(r'\bColor\(0x|\bColors\.(?!transparent\b)');

  test('fora de lib/core/theme, nenhuma cor é escrita à mão', () {
    final found = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/core/theme/')) continue;

      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.trimLeft().startsWith('//')) continue;
        if (handWritten.hasMatch(line)) {
          found.add('$path:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      found,
      isEmpty,
      reason:
          'Use context.colors (as cores do tema em uso) ou, para o que é '
          'igual nos dois temas, uma constante de AppColors.',
    );
  });

  test('a conferência reconhece uma cor escrita à mão', () {
    expect(handWritten.hasMatch('color: Color(0xFF333333),'), isTrue);
    expect(handWritten.hasMatch('color: Colors.white,'), isTrue);
    expect(handWritten.hasMatch('color: Colors.transparent,'), isFalse);
    expect(handWritten.hasMatch('color: context.colors.textPrimary,'), isFalse);
    expect(handWritten.hasMatch('color: AppColors.onGradient,'), isFalse);
  });
}
