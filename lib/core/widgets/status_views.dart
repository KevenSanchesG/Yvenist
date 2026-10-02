import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';

/// Indicador de carregamento centralizado, anunciado por leitores de tela.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Carregando'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

/// Estado vazio: explica o que apareceria ali e, se houver, o próximo passo.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Algo a mais abaixo da ação principal (um atalho secundário, por exemplo).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              // Só enfeite: mais apagado que o texto mais discreto.
              child: Icon(
                icon,
                size: 72,
                color: colors.textTertiary.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.sectionTitle, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: text.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

/// Estado de erro com caminho de recuperação: sempre oferece tentar de novo.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.cloud_off_outlined,
      title: 'Não foi possível carregar',
      message: message,
      actionLabel: 'Tentar novamente',
      onAction: onRetry,
    );
  }
}

/// Mostra uma mensagem curta, substituindo a anterior se ainda estiver na tela.
void showAppSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
