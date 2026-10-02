import 'package:flutter/widgets.dart';

/// O espaço da barra de navegação do sistema (os botões ou a barra de gestos
/// do Android, o indicador do iOS).
///
/// O app desenha a tela inteira, inclusive por baixo dessa barra, que é
/// transparente. Uma lista que vai até a borda de baixo soma esse espaço à
/// própria margem: o conteúdo passa por baixo da barra ao rolar, e o último
/// item para acima dela.
///
/// Dentro de uma aba do app o espaço já é zero (a barra inferior do app o
/// ocupa), e o mesmo vale dentro de um `SafeArea`: usar aqui nunca soma duas
/// vezes.
extension SystemInsets on BuildContext {
  /// [padding] com o espaço da barra de navegação do sistema somado embaixo.
  EdgeInsets withSystemBottomInset(EdgeInsets padding) {
    return padding.copyWith(
      bottom: padding.bottom + MediaQuery.paddingOf(this).bottom,
    );
  }
}
