import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';

/// Em que pé está a resposta do fornecedor a um item.
enum QuoteStatus {
  /// O orçamento deste item não foi pedido (ou o pedido foi retirado).
  none('none'),

  /// Pedido e ainda sem resposta.
  pending('pending'),

  /// O fornecedor informou o valor.
  quoted('quoted'),

  /// O fornecedor pediu que a pessoa altere alguma coisa.
  changesRequested('changes_requested'),

  /// O fornecedor não pode atender.
  declined('declined');

  const QuoteStatus(this.apiValue);

  final String apiValue;

  /// Um valor que o app ainda não conhece vira [pending]: nada é tratado como
  /// respondido sem que o app saiba ler a resposta.
  static QuoteStatus fromApi(Object? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return pending;
  }
}

/// O orçamento de um item: o valor que o fornecedor informou, que é uma coisa
/// diferente da estimativa calculada pelo app.
class ItemQuote {
  const ItemQuote({
    required this.status,
    this.amount,
    this.message,
    this.respondedAt,
  });

  const ItemQuote.none() : this(status: QuoteStatus.none);

  const ItemQuote.pending() : this(status: QuoteStatus.pending);

  final QuoteStatus status;

  /// O valor informado pelo fornecedor. Só existe quando ele deu o preço.
  final Money? amount;

  /// O que o fornecedor escreveu junto: uma condição, o que precisa mudar, por
  /// que não pode atender.
  final String? message;
  final DateTime? respondedAt;

  bool get isQuoted => status == QuoteStatus.quoted;

  /// O fornecedor devolveu o item para a pessoa: ela precisa alterar ou tirar.
  bool get needsTheClient =>
      status == QuoteStatus.changesRequested || status == QuoteStatus.declined;

  @override
  bool operator ==(Object other) =>
      other is ItemQuote &&
      other.status == status &&
      other.amount == amount &&
      other.message == message &&
      other.respondedAt == respondedAt;

  @override
  int get hashCode => Object.hash(status, amount, message, respondedAt);

  @override
  String toString() => 'ItemQuote(${status.apiValue}, $amount)';
}
