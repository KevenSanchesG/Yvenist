import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/core/licenses.dart';
import 'package:yvenist/core/theme/app_typography.dart';

/// O que o app promete usar tem de estar dentro do pacote.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pubspec = File('pubspec.yaml').readAsStringSync();

  test(
    'a fonte do tema está embutida, com um arquivo para cada peso usado',
    () {
      // Regressão: o tema pedia a fonte "Inter", mas os arquivos não estavam no
      // projeto e cada plataforma caía, em silêncio, na sua fonte padrão.
      expect(pubspec, contains('family: ${AppTypography.fontFamily}'));

      final fontFiles = RegExp(
        r'asset:\s*(assets/fonts/\S+\.ttf)',
      ).allMatches(pubspec).map((match) => match.group(1)!).toList();

      expect(fontFiles, hasLength(4));
      for (final path in fontFiles) {
        expect(File(path).existsSync(), isTrue, reason: '$path não existe');
      }
      for (final weight in [500, 600, 700]) {
        expect(pubspec, contains('weight: $weight'));
      }
    },
  );

  test(
    'a licença da fonte acompanha o app e aparece entre as licenças',
    () async {
      registerThirdPartyLicenses();

      final entries = await LicenseRegistry.licenses.toList();
      final inter = entries.firstWhere(
        (entry) => entry.packages.contains('Inter (fonte)'),
      );
      final text = inter.paragraphs.map((p) => p.text).join('\n');

      expect(text, contains('SIL Open Font License'));
      expect(text, contains('The Inter Project Authors'));
    },
  );
}
