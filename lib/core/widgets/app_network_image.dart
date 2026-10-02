import 'package:flutter/material.dart';

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
    if (imageUrl == null || imageUrl.isEmpty) return _placeholder(fallbackIcon);

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
        return progress == null ? child : _placeholder(null);
      },
      errorBuilder: (_, _, _) => _placeholder(Icons.broken_image_outlined),
    );
  }

  Widget _placeholder(IconData? icon) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: icon == null
          ? null
          : ExcludeSemantics(child: Icon(icon, color: Colors.grey.shade500)),
    );
  }
}
