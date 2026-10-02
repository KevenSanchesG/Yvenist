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
        'Party está Locked; alterações não são permitidas.',
      );
}

// Itens / Budget
class VenueAlreadySelected extends PartyDomainException {
  const VenueAlreadySelected()
    : super(
        'venue_already_selected',
        'Já existe um Venue/Salão selecionado nesta Party.',
      );
}

class PartyItemNotFound extends PartyDomainException {
  const PartyItemNotFound()
    : super('party_item_not_found', 'Item não encontrado na Party.');
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
        'Não é possível travar para pagamento sem itens.',
      );
}

class CannotCancelAfterPaidInMvp extends PartyDomainException {
  const CannotCancelAfterPaidInMvp()
    : super(
        'cannot_cancel_after_paid_mvp',
        'No MVP, não é permitido cancelar após pagamento confirmado.',
      );
}
