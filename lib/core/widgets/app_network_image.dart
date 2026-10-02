import 'package:flutter/material.dart';
import 'package:yvenist/core/theme/app_theme.dart';

/// Imagem da rede que nunca quebra o layout: mostra um fundo neutro enquanto
/// carrega e um ícone se a imagem falhar ou não existir.
///
/// [cacheWidth] faz a imagem ser decodificada no tamanho em que é exibida, e
/// não no tamanho original: economiza memória em listas com muitas fotos.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fallbackIcon = Icons.image_outlined,
    this.semanticLabel,
  });

  final String? url;
  final double width;
  final double height;
  final IconData fallbackIcon;

  /// Descrição para leitores de tela. Sem ela a imagem é tratada como
  /// decorativa (o texto ao lado já descreve o item).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholder(context, fallbackIcon);
    }

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: width.isFinite ? (width * devicePixelRatio).round() : null,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      loadingBuilder: (context, child, progress) {
        return progress == null ? child : _placeholder(context, null);
      },
      errorBuilder: (context, _, _) =>
          _placeholder(context, Icons.broken_image_outlined),
    );
  }

  Widget _placeholder(BuildContext context, IconData? icon) {
    final colors = context.colors;

    return Container(
      width: width,
      height: height,
      color: colors.surfaceMuted,
      child: icon == null
          ? null
          : ExcludeSemantics(child: Icon(icon, color: colors.textTertiary)),
    );
  }
}
