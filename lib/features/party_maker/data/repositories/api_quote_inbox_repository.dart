import 'package:yvenist/core/network/api_client.dart';
import 'package:yvenist/features/party_maker/data/party_mapper.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

/// Os pedidos de orçamento do fornecedor, na API.
class ApiQuoteInboxRepository implements QuoteInboxRepository {
  ApiQuoteInboxRepository(this._api);

  static const String _path = '/vendors/me/quote-requests';

  final ApiClient _api;

  @override
  Future<List<QuoteRequest>> list() async {
    final json = await _api.get(_path, authenticated: true) as Json;
    return (json['items'] as List)
        .cast<Json>()
        .map(quoteRequestFromJson)
        .toList();
  }

  @override
  Future<QuoteRequest> respond(String itemId, VendorResponse response) async {
    final action = switch (response.status) {
      QuoteStatus.quoted => 'quote',
      QuoteStatus.changesRequested => 'request-changes',
      QuoteStatus.declined => 'decline',
      QuoteStatus.none || QuoteStatus.pending => throw ArgumentError.value(
        response.status,
        'response',
        'não é uma resposta',
      ),
    };
    final json =
        await _api.post(
              '$_path/$itemId/$action',
              authenticated: true,
              body: {
                if (response.amount case final amount?)
                  'amount_cents': amount.cents,
                'message': ?response.message,
              },
            )
            as Json;
    return quoteRequestFromJson(json);
  }
}
