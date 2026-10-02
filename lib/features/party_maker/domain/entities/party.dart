import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_payment_snapshot.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_item_category.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/cancellation_result.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/external_ref.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';

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
  }) : status = status ?? PartyStatus.draft,
       budget = budget ?? PartyBudget.empty();

  // ---------- Guards ----------
  void _ensureMutable() {
    if (status == PartyStatus.locked) {
      throw const PartyLockedMutationNotAllowed();
    }
    if (status == PartyStatus.paid) {
      throw const InvalidPartyTransition(
        'Uma festa já paga não pode ser alterada.',
      );
    }
    if (status == PartyStatus.cancelled) {
      throw const InvalidPartyTransition(
        'Uma festa cancelada não pode ser alterada.',
      );
    }
  }

  /// Por que a festa, no status em que está, não pode [action]
  /// (ex.: "receber itens"). A frase vai para a tela.
  String _notEditableMessage(String action) {
    final reason = switch (status) {
      PartyStatus.locked => 'está com o orçamento solicitado',
      PartyStatus.paid => 'já foi paga',
      PartyStatus.cancelled => 'foi cancelada',
      PartyStatus.draft || PartyStatus.planning => 'não está em planejamento',
    };
    return 'Esta festa $reason e não pode $action.';
  }

  void _touch() => updatedAt = DateTime.now();

  // ---------- Lifecycle ----------
  void startPlanning() {
    if (status != PartyStatus.draft) {
      throw const InvalidPartyTransition(
        'Só um rascunho pode passar para o planejamento.',
      );
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
      throw InvalidPartyTransition(_notEditableMessage('receber itens'));
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
      throw InvalidPartyTransition(_notEditableMessage('perder itens'));
    }
    budget = budget.removeItem(id);
    _touch();
  }

  void updateItemQuantity(PartyItemId id, Quantity q) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw InvalidPartyTransition(_notEditableMessage('ter itens alterados'));
    }
    budget = budget.updateQuantity(id, q);
    _touch();
  }

  void updateItemPrice(PartyItemId id, Money newUnitPriceSnapshot) {
    if (status != PartyStatus.draft && status != PartyStatus.planning) {
      throw InvalidPartyTransition(_notEditableMessage('ter itens alterados'));
    }
    budget = budget.updateUnitPrice(id, newUnitPriceSnapshot);
    _touch();
  }

  // ---------- Lock / Payment ----------
  void lockForPayment() {
    if (status != PartyStatus.planning) {
      throw const InvalidPartyTransition(
        'Só uma festa em planejamento pode ter o orçamento solicitado.',
      );
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
      throw const InvalidPartyTransition(
        'Só uma festa com orçamento solicitado pode ser liberada para edição.',
      );
    }
    paymentSnapshot = null;
    status = PartyStatus.planning;
    _touch();
  }

  void confirmPayment() {
    if (status != PartyStatus.locked) {
      throw const InvalidPartyTransition(
        'Só uma festa com orçamento solicitado pode ser paga.',
      );
    }
    if (paymentSnapshot == null) {
      throw const PartyDomainException(
        'missing_payment_snapshot',
        'Não há orçamento registrado para confirmar o pagamento.',
      );
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
      throw const InvalidPartyTransition('Esta festa já está cancelada.');
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
