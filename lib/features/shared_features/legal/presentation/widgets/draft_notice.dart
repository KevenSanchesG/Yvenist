import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';

/// Aviso de que os documentos legais ainda são uma versão preliminar.
///
/// Sai daqui quando os textos forem revisados por um advogado e os trechos
/// entre colchetes forem preenchidos.
class DraftNotice extends StatelessWidget {
  const DraftNotice({super.key});

  static const String message =
      'Versão preliminar: este texto ainda não passou por revisão jurídica e '
      'pode mudar antes do lançamento.';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.info_outline, color: colors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: context.text.body)),
        ],
      ),
    );
  }
}
