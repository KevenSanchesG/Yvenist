import '../enums/party_status.dart';
import '../rules/party_domain_exceptions.dart';
import '../value_objects/cancellation_result.dart';
import '../value_objects/event_date.dart';
import '../value_objects/guest_count.dart';
import '../value_objects/money.dart';
import '../value_objects/party_id.dart';
import '../value_objects/party_item_id.dart';
import '../value_objects/party_title.dart';
import '../value_objects/quantity.dart';
import '../value_objects/external_ref.dart';
import '../enums/party_item_category.dart';
import 'party_budget.dart';
import 'party_item.dart';
import 'party_payment_snapshot.dart';

class Party {
  final PartyId id;
  final String ownerId; // mantenha simples por enquanto; depois vira VO UserId
  PartyTitle title;
  EventDate? eventDate;
  GuestCount? guestCount;

  PartyStatus status;

  PartyBudget budget;
  PartyPaymentSnapshot? paymentSnapshot;

  final DateTime createdAt;
  DateTime updatedAt;

  Party({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.eventDate,
    this.guestCount,
    PartyStatus? status,
    PartyBudget? budget,
    this.paymentSnapshot,
  })  : status = status ?? PartyStatus.draft,
        budget = budget ?? PartyBudget.empty();

  // ---------- Guards ----------
  void _ensureMutable() {
    if (status == PartyStatus.locked) throw const PartyLockedMutationNotAllowed();
    if (status == PartyStatus.paid) throw const InvalidPartyTransition('Party paid não pode ser alterada.');
    if (status == PartyStatus.cancelled) throw const InvalidPartyTransition('Party cancelada não pode ser alterada.');
  }

  void _touch() => updatedAt = DateTime.now();

  // ---------- Lifecycle ----------
  void startPlanning() {
    if (status != PartyStatus.draft) {
      throw const InvalidPartyTransition('Só é possível iniciar planning a partir de draft.');
    }
    status = PartyStatus.planning;
    _touch();
  }

  void updateTitle(PartyTitle newTitle) {
    _ensureMutable();
    title = newTitle;
    _touch();
  }

    // Alias semântico pro produto (rename)
  void rename(PartyTitle newTitle) => updateTitle(newTitle);

  void setEventDate(EventDate date) {
    _ensureMutable();
    eventDate = date;
    _touch();
  }

  void setGuestCount(GuestCount count) {
    _ensureMutable();
    guestCount = count;
    _touch();
  }

  // ---------- Budget / Items ----------
  void addItem({
    required PartyItemId partyItemId,
    required ExternalRef externalRef,
    required PartyItemCategory category,
    required String nameSnapshot,
    required Money unitPriceSnapshot,
    required Quantity quantity,
    String? imageUrlSnapshot,
  }) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw const InvalidPartyTransition('Só é possível adicionar itens em draft/planning.');
    }

    final item = PartyItem(
      id: partyItemId,
      externalRef: externalRef,
      category: category,
      nameSnapshot: nameSnapshot,
      unitPriceSnapshot: unitPriceSnapshot,
      quantity: quantity,
      imageUrlSnapshot: imageUrlSnapshot,
    );

    budget = budget.addOrMergeItem(newItem: item);
    _touch();
  }

  void removeItem(PartyItemId id) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw const InvalidPartyTransition('Só é possível remover itens em draft/planning.');
    }
    budget = budget.removeItem(id);
    _touch();
  }

  void updateItemQuantity(PartyItemId id, Quantity q) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw const InvalidPartyTransition('Só é possível atualizar quantidade em draft/planning.');
    }
    budget = budget.updateQuantity(id, q);
    _touch();
  }

  void updateItemPrice(PartyItemId id, Money newUnitPriceSnapshot) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw const InvalidPartyTransition('Só é possível atualizar preço em draft/planning.');
    }
    budget = budget.updateUnitPrice(id, newUnitPriceSnapshot);
    _touch();
  }

  // ---------- Lock / Payment ----------
  void lockForPayment() {
    if (status != PartyStatus.planning) {
      throw const InvalidPartyTransition('Só é possível lockForPayment a partir de planning.');
    }
    if (budget.items.isEmpty) throw const CannotLockWithoutItems();

    final now = DateTime.now();
    final total = budget.total;

    final breakdown = budget.items
        .map(
          (i) => SnapshotLineItem(
            externalRef: i.externalRef,
            category: i.category,
            nameSnapshot: i.nameSnapshot,
            unitPriceSnapshot: i.unitPriceSnapshot,
            quantity: i.quantity,
            subtotal: i.subtotal,
          ),
        )
        .toList();

    paymentSnapshot = PartyPaymentSnapshot(
      partyId: id,
      generatedAt: now,
      totalAmount: total,
      breakdown: breakdown,
    );

    status = PartyStatus.locked;
    _touch();
  }

  void unlock() {
    if (status != PartyStatus.locked) {
      throw const InvalidPartyTransition('Só é possível unlock a partir de locked.');
    }
    paymentSnapshot = null;
    status = PartyStatus.planning;
    _touch();
  }

  void confirmPayment() {
    if (status != PartyStatus.locked) {
      throw const InvalidPartyTransition('Só é possível confirmar pagamento a partir de locked.');
    }
    if (paymentSnapshot == null) {
      throw const PartyDomainException('missing_payment_snapshot', 'Snapshot é obrigatório para confirmar pagamento.');
    }
    status = PartyStatus.paid;
    _touch();
  }

  // ---------- Cancel ----------
  CancellationResult cancel() {
    if (status == PartyStatus.paid) {
      throw const CannotCancelAfterPaidInMvp();
    }
    if (status == PartyStatus.cancelled) {
      throw const InvalidPartyTransition('Party já está cancelada.');
    }

    // MVP: neutro
    final totalNow = budget.items.isEmpty ? Money.zero() : budget.total;
    final currency = totalNow.currency;

    // Se estiver locked, invalida snapshot
    if (status == PartyStatus.locked) {
      paymentSnapshot = null;
    }

    status = PartyStatus.cancelled;
    _touch();

    return CancellationResult(
      totalAtCancellation: totalNow,
      refundAmount: Money.zero(currency: currency),
      penaltyAmount: Money.zero(currency: currency),
    );
  }
}
