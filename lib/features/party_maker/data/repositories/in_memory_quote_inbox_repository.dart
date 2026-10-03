import 'package:yvenist/core/error/app_failure.dart';
import 'package:yvenist/features/party_maker/data/repositories/in_memory_party_repository.dart';
import 'package:yvenist/features/party_maker/domain/entities/party.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/repositories/quote_inbox_repository.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

/// Os pedidos de orçamento em memória: modo demonstração e testes.
///
/// No modo demonstração não existe outra conta para fazer o papel do
/// fornecedor: quem está usando o app responde aos pedidos que ele mesmo fez
/// ([DemoVendorAnswers]). As regras da resposta são as do agregado, as mesmas
/// que a API aplica.
class InMemoryQuoteInboxRepository
    implements QuoteInboxRepository, DemoVendorAnswers {
  InMemoryQuoteInboxRepository(this._parties);

  final InMemoryPartyRepository _parties;

  @override
  Future<List<QuoteRequest>> list() async {
    return [
      for (final party in _parties.all())
        if (_isVisibleToVendors(party))
          for (final item in party.budget.items)
            if (item.quote.status != QuoteStatus.none) _toRequest(party, item),
    ];
  }

  @override
  Future<QuoteRequest> respond(String itemId, VendorResponse response) async {
    final id = PartyItemId(itemId);
    for (final party in _parties.all()) {
      if (party.budget.findById(id) == null) continue;

      try {
        party.registerVendorResponse(id, response);
      } on InvalidQuoteResponse catch (error) {
        // Como a API responde: um repositório só lança falhas.
        throw ValidationFailure(error.message, code: error.code);
      } on PartyDomainException catch (error) {
        throw ConflictFailure(error.message, error.code);
      }
      final saved = await _parties.save(party);
      return _toRequest(saved, saved.budget.findById(id)!);
    }
    throw const NotFoundFailure(
      'Pedido de orçamento não encontrado.',
      'quote_request_not_found',
    );
  }

  /// O fornecedor enxerga as festas com o orçamento solicitado e as que foram
  /// canceladas depois disso. Uma festa que voltou para a edição some daqui:
  /// ele não acompanha o que o cliente ainda está mudando.
  static bool _isVisibleToVendors(Party party) {
    return party.status.isSubmitted || party.status == PartyStatus.cancelled;
  }

  static QuoteRequest _toRequest(Party party, PartyItem item) {
    final parentId = item.relation.parentId;
    return QuoteRequest(
      itemId: item.id.value,
      partyId: party.id.value,
      partyStatus: party.status,
      round: party.quoteRound,
      updatedAt: party.updatedAt,
      eventType: party.eventType,
      eventDate: party.eventDate?.value,
      guestCount: party.guestCount?.value,
      name: item.nameSnapshot,
      category: item.category,
      relation: item.relation.kind,
      parentName: parentId == null
          ? null
          : party.budget.findById(parentId)?.nameSnapshot,
      pricing: item.pricing,
      quantity: item.quantity.value,
      configuration: item.configuration,
      estimate: item.estimate(guests: party.guestCount?.value),
      quote: item.quote,
    );
  }
}
