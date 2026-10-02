/// Uma regra do Party Maker foi violada.
///
/// [message] chega à tela como está: é escrita para quem usa o app, sem termos
/// internos. [code] é estável e igual ao enviado pela API para a mesma regra.
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

// Status / Transições
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

// Itens / Budget
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

class BudgetWouldBecomeNegative extends PartyDomainException {
  const BudgetWouldBecomeNegative()
    : super(
        'budget_total_negative',
        'O total do orçamento não pode ser negativo.',
      );
}

class CannotLockWithoutItems extends PartyDomainException {
  const CannotLockWithoutItems()
    : super(
        'cannot_lock_without_items',
        'Adicione ao menos um item antes de solicitar o orçamento.',
      );
}

class CannotCancelAfterPaidInMvp extends PartyDomainException {
  const CannotCancelAfterPaidInMvp()
    : super(
        'cannot_cancel_after_paid_mvp',
        'Uma festa já paga não pode ser cancelada.',
      );
}
