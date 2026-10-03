import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

/// O retrato da estimativa no momento em que o orçamento foi solicitado: quando
/// foi, e quanto o app estimava. Existe enquanto a festa está com o orçamento
/// solicitado; o que foi pedido em cada rodada fica no histórico.
class QuoteRequestSnapshot {
  const QuoteRequestSnapshot({
    required this.requestedAt,
    required this.estimatedTotal,
    required this.unpricedItems,
  });

  final DateTime requestedAt;

  /// A soma do que dava para estimar naquele momento.
  final Money estimatedTotal;

  /// Quantos itens ficaram fora dessa soma.
  final int unpricedItems;
}
