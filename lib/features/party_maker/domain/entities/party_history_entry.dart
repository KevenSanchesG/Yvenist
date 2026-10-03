import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';

/// O que pode acontecer com uma festa depois que ela sai do planejamento.
enum PartyHistoryKind {
  quoteRequested('quote_requested'),
  reopened('reopened'),
  vendorQuoted('vendor_quoted'),
  vendorRequestedChanges('vendor_requested_changes'),
  vendorDeclined('vendor_declined'),
  confirmed('confirmed'),
  cancelled('cancelled');

  const PartyHistoryKind(this.apiValue);

  final String apiValue;

  /// `null` para um acontecimento que o app ainda não conhece: ele fica fora
  /// da lista, em vez de aparecer com o texto errado.
  static PartyHistoryKind? fromApi(Object? value) {
    for (final kind in values) {
      if (kind.apiValue == value) return kind;
    }
    return null;
  }
}

enum PartyHistoryActor { client, vendor }

/// Um acontecimento da festa. O histórico só cresce: nada nele é alterado, e é
/// por ele que se sabe o que foi pedido, respondido e mudado em cada rodada.
class PartyHistoryEntry {
  const PartyHistoryEntry({
    required this.kind,
    required this.actor,
    required this.round,
    required this.at,
    this.itemId,
    this.itemName,
    this.message,
    this.amount,
  });

  final PartyHistoryKind kind;
  final PartyHistoryActor actor;

  /// Em que rodada de orçamento aconteceu (1 na primeira vez que foi pedido).
  final int round;
  final DateTime at;

  /// O item a que se refere, quando é a resposta de um fornecedor. O nome é
  /// uma cópia: o registro continua legível depois que o item sai da festa.
  final PartyItemId? itemId;
  final String? itemName;

  /// O que o fornecedor escreveu.
  final String? message;

  /// A estimativa do pedido, o valor informado ou o total aceito.
  final Money? amount;
}
