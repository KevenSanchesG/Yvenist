import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';
import 'package:yvenist/core/widgets/status_views.dart';
import 'package:yvenist/features/shared_features/legal/domain/legal_document.dart';
import 'package:yvenist/features/shared_features/legal/presentation/widgets/draft_notice.dart';

/// Mostra o texto de um documento legal embutido no app.
class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.document});

  final LegalDocument document;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  Future<List<LegalBlock>>? _blocks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _blocks ??= _load();
  }

  Future<List<LegalBlock>> _load() async {
    // cache: false porque o texto é pequeno e aberto raramente: não vale
    // mantê-lo em memória até o app fechar.
    final text = await DefaultAssetBundle.of(
      context,
    ).loadString(widget.document.assetPath, cache: false);
    return parseLegalText(text);
  }

  void _retry() => setState(() => _blocks = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: FutureBuilder<List<LegalBlock>>(
        future: _blocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorStateView(
              message: 'Não foi possível abrir este documento.',
              onRetry: _retry,
            );
          }
          final blocks = snapshot.data;
          if (blocks == null) return const LoadingView();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              const DraftNotice(),
              // O título já está na barra do topo.
              for (final block in blocks)
                if (block.kind != LegalBlockKind.title) _BlockView(block),
            ],
          );
        },
      ),
    );
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView(this.block);

  final LegalBlock block;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = context.text.body.copyWith(height: 1.5);

    switch (block.kind) {
      case LegalBlockKind.title:
      case LegalBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Semantics(
            header: true,
            child: Text(block.text, style: context.text.sectionTitle),
          ),
        );
      case LegalBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(block.text, style: bodyStyle),
        );
      case LegalBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Text(
                  '•  ',
                  style: bodyStyle.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              Expanded(child: Text(block.text, style: bodyStyle)),
            ],
          ),
        );
    }
  }
}
