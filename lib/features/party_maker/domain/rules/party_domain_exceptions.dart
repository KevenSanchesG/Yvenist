/// Uma regra do Party Maker foi violada.
///
/// [message] chega à tela como está: é escrita para quem usa o app, sem termos
/// internos. [code] é estável e igual ao enviado pela API para a mesma regra
/// (`backend/app/modules/parties/domain.py`).
class PartyDomainException implements Exception {
  final String code;
  final String message;

  const PartyDomainException(this.code, this.message);

  @override
  String toString() => 'PartyDomainException($code): $message';
}

class PartyNotFound extends PartyDomainException {
  const PartyNotFound() : super('party_not_found', 'Festa não encontrada.');
}

// ---------------------------------------------------------------
// Status e transições
// ---------------------------------------------------------------

class InvalidPartyTransition extends PartyDomainException {
  const InvalidPartyTransition(String message)
    : super('invalid_party_transition', message);
}

class PartyLockedMutationNotAllowed extends PartyDomainException {
  const PartyLockedMutationNotAllowed()
    : super(
        'party_locked_mutation_not_allowed',
        'O orçamento desta festa já foi solicitado. '
            'Toque em "Editar festa" para poder alterá-la.',
      );
}

class CannotLockWithoutItems extends PartyDomainException {
  const CannotLockWithoutItems()
    : super(
        'cannot_lock_without_items',
        'Adicione ao menos um item antes de solicitar o orçamento.',
      );
}

class PaidPartyCannotBeDeleted extends PartyDomainException {
  const PaidPartyCannotBeDeleted()
    : super(
        'paid_party_cannot_be_deleted',
        'Uma festa já paga não pode ser apagada.',
      );
}

class PartyHasOpenQuote extends PartyDomainException {
  const PartyHasOpenQuote()
    : super(
        'party_has_open_quote',
        'Cancele a festa antes de apagar: os fornecedores já receberam o '
            'pedido.',
      );
}

// ---------------------------------------------------------------
// O evento
// ---------------------------------------------------------------

class EventDateInPast extends PartyDomainException {
  const EventDateInPast()
    : super('event_date_in_past', 'A data da festa precisa ser no futuro.');
}

class EventDateRequired extends PartyDomainException {
  const EventDateRequired()
    : super(
        'event_date_required',
        'Informe a data da festa antes de solicitar o orçamento.',
      );
}

class GuestCountRequired extends PartyDomainException {
  const GuestCountRequired()
    : super('guest_count_required', 'Informe o número de convidados da festa.');
}

class EventDetailsRequired extends PartyDomainException {
  const EventDetailsRequired()
    : super(
        'event_details_required',
        'Informe a data e o número de convidados da festa para escolher o '
            'salão.',
      );
}

class GuestCountExceedsCapacity extends PartyDomainException {
  const GuestCountExceedsCapacity(int capacity)
    : super(
        'guest_count_exceeds_capacity',
        'O espaço escolhido comporta até $capacity pessoas.',
      );
}

// ---------------------------------------------------------------
// Itens
// ---------------------------------------------------------------

class VenueAlreadySelected extends PartyDomainException {
  const VenueAlreadySelected()
    : super(
        'venue_already_selected',
        'Esta festa já tem um salão. Remova o atual para escolher outro.',
      );
}

class PartyItemNotFound extends PartyDomainException {
  const PartyItemNotFound()
    : super('party_item_not_found', 'Este item não está mais na festa.');
}

class DuplicatePartyItem extends PartyDomainException {
  const DuplicatePartyItem()
    : super(
        'duplicate_party_item',
        'Este item já está na festa. Abra o item para alterá-lo.',
      );
}

class TooManyPartyItems extends PartyDomainException {
  const TooManyPartyItems(int max)
    : super('too_many_party_items', 'Uma festa pode ter no máximo $max itens.');
}

class InvalidQuantity extends PartyDomainException {
  const InvalidQuantity([
    String message = 'A quantidade precisa ficar entre 1 e 999.',
  ]) : super('invalid_quantity', message);
}

/// A configuração de um item não passou nas regras da categoria.
/// [fieldErrors] liga a chave de cada campo ao que há de errado com ele.
class InvalidItemConfiguration extends PartyDomainException {
  const InvalidItemConfiguration(this.fieldErrors)
    : super('invalid_item_configuration', 'Revise as informações do item.');

  final Map<String, String> fieldErrors;
}

class InvalidItemRelation extends PartyDomainException {
  const InvalidItemRelation()
    : super(
        'invalid_item_relation',
        'A ligação entre os itens da festa não é válida.',
      );
}

class ParentItemMissing extends PartyDomainException {
  const ParentItemMissing()
    : super(
        'parent_item_missing',
        'Um serviço do próprio anunciante só fica na festa junto com o '
            'anúncio dele.',
      );
}

class RequiredItemMissing extends PartyDomainException {
  const RequiredItemMissing()
    : super(
        'required_item_missing',
        'Este anúncio só pode ser contratado com os serviços obrigatórios '
            'dele.',
      );
}

/// A pessoa tentou tirar, sozinho, um serviço que é obrigatório para o item a
/// que ele pertence.
class RequiredItemCannotLeaveAlone extends PartyDomainException {
  const RequiredItemCannotLeaveAlone(String itemName, String parentName)
    : super(
        'required_item_missing',
        '$itemName é obrigatório para contratar $parentName. Para tirar, '
            'remova $parentName.',
      );
}

class ItemNoLongerAvailable extends PartyDomainException {
  const ItemNoLongerAvailable(String itemName)
    : super(
        'item_no_longer_available',
        '$itemName não está mais disponível. Remova o item para solicitar o '
            'orçamento.',
      );
}

// ---------------------------------------------------------------
// A resposta do fornecedor
// ---------------------------------------------------------------

class QuoteRequestClosed extends PartyDomainException {
  const QuoteRequestClosed()
    : super(
        'quote_request_closed',
        'Este pedido não está mais aberto para resposta.',
      );
}

class InvalidQuoteResponse extends PartyDomainException {
  const InvalidQuoteResponse(String message)
    : super('invalid_quote_response', message);
}
