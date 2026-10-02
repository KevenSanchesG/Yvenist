import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_colors.dart';
import 'package:yvenist/core/theme/app_typography.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.headerBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.info_outline, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text(message, style: AppTypography.body)),
        ],
      ),
    );
  }
}
