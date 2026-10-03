import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

/// O que um fornecedor responde a um pedido de orçamento de um item.
class VendorResponse {
  /// O valor que ele cobra pelo item, como a pessoa o configurou.
  const VendorResponse.quote(Money this.amount, {this.message})
    : status = QuoteStatus.quoted;

  /// Um pedido para a pessoa alterar alguma coisa, dizendo o quê.
  const VendorResponse.requestChanges(String this.message)
    : status = QuoteStatus.changesRequested,
      amount = null;

  /// O aviso de que não pode atender, dizendo por quê.
  const VendorResponse.decline(String this.message)
    : status = QuoteStatus.declined,
      amount = null;

  /// Os mesmos limites da API.
  static const int maxAmountCents = 1000000000; // R$ 10 milhões
  static const int maxMessageLength = 500;
  static const int minExplanationLength = 5;

  final QuoteStatus status;
  final Money? amount;
  final String? message;
}
