/// Documentos legais que acompanham o app (`assets/legal`).
///
/// Os textos são **versões preliminares**: foram escritos a partir do que o
/// app realmente faz, mas ainda não passaram por revisão jurídica. O que
/// depende de uma decisão de negócio aparece entre colchetes no próprio texto.
enum LegalDocument {
  termsOfUse('Termos de Uso', 'assets/legal/termos-de-uso.md'),
  privacyPolicy(
    'Política de Privacidade',
    'assets/legal/politica-de-privacidade.md',
  );

  const LegalDocument(this.title, this.assetPath);

  final String title;
  final String assetPath;
}

enum LegalBlockKind { title, heading, bullet, paragraph }

/// Um trecho de um documento legal, já separado do Markdown.
class LegalBlock {
  const LegalBlock(this.kind, this.text);

  final LegalBlockKind kind;
  final String text;
}

/// Lê o Markdown simples usado nos documentos legais: `# título`,
/// `## seção`, `- item` e parágrafos separados por linha em branco.
///
/// É só esse subconjunto, de propósito: os textos não usam mais do que isso e
/// assim o app não depende de um pacote de Markdown.
List<LegalBlock> parseLegalText(String source) {
  final blocks = <LegalBlock>[];
  final paragraph = <String>[];

  void closeParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(LegalBlock(LegalBlockKind.paragraph, paragraph.join(' ')));
    paragraph.clear();
  }

  for (final rawLine in source.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      closeParagraph();
    } else if (line.startsWith('## ')) {
      closeParagraph();
      blocks.add(LegalBlock(LegalBlockKind.heading, line.substring(3).trim()));
    } else if (line.startsWith('# ')) {
      closeParagraph();
      blocks.add(LegalBlock(LegalBlockKind.title, line.substring(2).trim()));
    } else if (line.startsWith('- ')) {
      closeParagraph();
      blocks.add(LegalBlock(LegalBlockKind.bullet, line.substring(2).trim()));
    } else {
      paragraph.add(line);
    }
  }
  closeParagraph();
  return blocks;
}
