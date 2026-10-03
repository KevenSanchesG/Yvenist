import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

/// Os pedidos de orçamento da conta autenticada, como fornecedora.
abstract interface class QuoteInboxRepository {
  /// Os pedidos dos próprios anúncios, do que mudou por último para o mais
  /// antigo. Lança `NotFoundFailure` se a conta não tem cadastro de
  /// fornecedor.
  Future<List<QuoteRequest>> list();

  /// Responde ao pedido do item [itemId] e devolve o pedido como ficou.
  Future<QuoteRequest> respond(String itemId, VendorResponse response);
}

/// Capacidade extra do modo demonstração: a mesma conta responde aos pedidos
/// que ela própria fez, já que não há outra conta para fazer o papel do
/// fornecedor.
abstract interface class DemoVendorAnswers {}
