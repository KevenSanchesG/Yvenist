import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yvenist/features/shared_features/legal/domain/legal_document.dart';

void main() {
  group('parseLegalText', () {
    test('separa título, seções, itens e parágrafos', () {
      final blocks = parseLegalText('''
# Termos

Versão 1

## 1. Conta

Primeira linha
continua aqui.

- item um
- item dois
''');

      expect(
        [for (final block in blocks) (block.kind, block.text)],
        [
          (LegalBlockKind.title, 'Termos'),
          (LegalBlockKind.paragraph, 'Versão 1'),
          (LegalBlockKind.heading, '1. Conta'),
          (LegalBlockKind.paragraph, 'Primeira linha continua aqui.'),
          (LegalBlockKind.bullet, 'item um'),
          (LegalBlockKind.bullet, 'item dois'),
        ],
      );
    });

    test('aceita finais de linha do Windows e ignora linhas em branco', () {
      final blocks = parseLegalText('## Seção\r\n\r\n\r\nTexto\r\n');

      expect(blocks.map((block) => block.text), ['Seção', 'Texto']);
    });

    test('texto vazio não gera trechos', () {
      expect(parseLegalText(''), isEmpty);
      expect(parseLegalText('\n\n'), isEmpty);
    });
  });

  group('documentos embutidos', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final document in LegalDocument.values) {
      final text = File(document.assetPath).readAsStringSync();
      final blocks = parseLegalText(text);

      test('${document.title}: está no pacote e tem o título da tela', () {
        expect(pubspec, contains('- assets/legal/'));
        expect(blocks.first.kind, LegalBlockKind.title);
        expect(blocks.first.text, document.title);
        expect(
          blocks.where((block) => block.kind == LegalBlockKind.heading),
          isNotEmpty,
        );
      });

      test('${document.title}: enquanto houver lacunas, diz que é '
          'preliminar', () {
        // Um trecho entre colchetes é uma decisão que ainda não foi tomada
        // (razão social, contato, revisão jurídica). O texto só pode deixar de
        // se dizer preliminar quando não sobrar nenhum.
        final hasOpenPoints = RegExp(r'\[[^\]]+\]').hasMatch(text);
        final saysPreliminary = blocks[1].text.contains('(preliminar)');

        expect(hasOpenPoints, isTrue, reason: 'atualize este teste e o aviso');
        expect(saysPreliminary, isTrue);
      });

      test('${document.title}: a versão é a que o servidor registra no '
          'aceite', () {
        // O cadastro grava qual versão dos termos a pessoa aceitou
        // (`terms_version`). Mudou o texto, muda a versão nos dois lugares.
        final settings = File('backend/app/core/config.py').readAsStringSync();
        final serverVersion = RegExp(
          r'terms_version: str = "([^"]+)"',
        ).firstMatch(settings)!.group(1)!;

        expect(blocks[1].text, startsWith('Versão $serverVersion'));
      });
    }
  });
}
