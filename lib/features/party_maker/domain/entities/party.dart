import 'package:yvenist/core/pricing/pricing_model.dart';
import 'package:yvenist/core/utils/clock.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_budget.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_history_entry.dart';
import 'package:yvenist/features/party_maker/domain/entities/party_item.dart';
import 'package:yvenist/features/party_maker/domain/entities/quote_request_snapshot.dart';
import 'package:yvenist/features/party_maker/domain/enums/party_status.dart';
import 'package:yvenist/features/party_maker/domain/rules/party_domain_exceptions.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_date.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/event_details.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/guest_count.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/item_quote.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/money.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_item_id.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/party_title.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/quantity.dart';
import 'package:yvenist/features/party_maker/domain/value_objects/vendor_response.dart';

/// A festa: a composição de um evento.
///
/// Reúne os dados do evento (tipo, data, convidados) e os itens escolhidos,
/// cada um configurado do jeito da sua categoria. Só ela altera os próprios
/// itens e o próprio status: quem está de fora chama os métodos e recebe uma
/// [PartyDomainException] se a regra não deixar.
///
/// As mesmas regras existem na API (`reconcile`, em
/// `backend/app/modules/parties/domain.py`), que é a autoridade: mudou uma
/// regra aqui, mude lá, com o mesmo código de erro.
class Party {
  final PartyId id;
  final String ownerId;
  PartyTitle title;

  /// O tipo de evento, pelo `slug` do catálogo.
  String? eventType;
  EventDate? eventDate;
  GuestCount? guestCount;

  PartyStatus status;

  PartyBudget budget;

  /// O retrato da estimativa de quando o orçamento foi solicitado. Só existe
  /// enquanto a festa está com o orçamento solicitado.
  QuoteRequestSnapshot? quoteSnapshot;

  /// Quantas vezes o orçamento foi solicitado.
  int quoteRound;

  final DateTime createdAt;
  DateTime updatedAt;

  final Clock _clock;
  List<PartyHistoryEntry> _history;

  Party({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.eventType,
    this.eventDate,
    this.guestCount,
    PartyStatus? status,
    PartyBudget? budget,
    this.quoteSnapshot,
    this.quoteRound = 0,
    List<PartyHistoryEntry> history = const [],
    Clock clock = systemClock,
  }) : status = status ?? PartyStatus.draft,
       budget = budget ?? PartyBudget.empty(),
       _history = List.unmodifiable(history),
       _clock = clock;

  /// Uma cópia independente: mexer nela não mexe nesta.
  ///
  /// É o que um repositório em memória guarda e devolve. Sem isso, uma regra
  /// que falha no meio de uma operação deixaria a festa guardada pela metade.
  Party clone() {
    return Party(
      id: id,
      ownerId: ownerId,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      eventType: eventType,
      eventDate: eventDate,
      guestCount: guestCount,
      status: status,
      budget: budget,
      quoteSnapshot: quoteSnapshot,
      quoteRound: quoteRound,
      history: _history,
      clock: _clock,
    );
  }

  // ---------------------------------------------------------------
  // Leitura
  // ---------------------------------------------------------------

  /// O que aconteceu com a festa, do mais antigo para o mais novo.
  List<PartyHistoryEntry> get history => _history;

  /// A estimativa do evento: a conta feita com os preços dos anúncios.
  BudgetEstimate get estimate => budget.estimateFor(guestCount?.value);

  /// O orçamento recebido: a soma do que os fornecedores informaram.
  Money? get quotedTotal => budget.quotedTotal;

  /// O que falta para solicitar o orçamento. Cada pendência é a regra que
  /// barraria o pedido, com a frase que a tela mostra; vazia, a festa está
  /// pronta.
  List<PartyDomainException> get quoteBlockers {
    final date = eventDate;
    return [
      if (budget.isEmpty) const CannotLockWithoutItems(),
      if (date == null)
        const EventDateRequired()
      else if (!date.value.isAfter(_clock()))
        const EventDateInPast(),
      if (guestCount == null) const GuestCountRequired(),
      for (final item in budget.items)
        if (!item.externalRef.isAvailable)
          ItemNoLongerAvailable(item.nameSnapshot),
    ];
  }

  /// Os itens que um fornecedor devolveu: a pessoa precisa alterar ou tirar.
  List<PartyItem> get itemsNeedingAttention => [
    for (final item in budget.items)
      if (item.quote.needsTheClient) item,
  ];

  // ---------------------------------------------------------------
  // O evento
  // ---------------------------------------------------------------

  void startPlanning() {
    if (status != PartyStatus.draft) {
      throw const InvalidPartyTransition(
        'Só um rascunho pode passar para o planejamento.',
      );
    }
    status = PartyStatus.planning;
    _touch();
  }

  /// Troca o nome, o tipo, a data e o número de convidados da festa.
  void updateEventDetails(EventDetails details) {
    _ensureEditable();

    final date = details.eventDate;
    // Só a data que está sendo informada agora: uma festa antiga, cuja data
    // já passou, continua podendo ter o nome trocado.
    if (date != null && date != eventDate && !date.value.isAfter(_clock())) {
      throw const EventDateInPast();
    }
    _checkCapacity(details.guestCount, budget.items);

    final eventChanged =
        details.eventType != eventType ||
        date != eventDate ||
        details.guestCount != guestCount;

    title = details.title;
    eventType = details.eventType;
    eventDate = date;
    guestCount = details.guestCount;
    if (eventChanged) {
      // O valor que cada fornecedor informou valia para o evento de antes.
      budget = budget.withQuotes((_) => const ItemQuote.none());
    }
    _touch();
  }

  // ---------------------------------------------------------------
  // Os itens
  // ---------------------------------------------------------------

  /// Põe [items] na festa de uma vez: um anúncio entra junto com os serviços
  /// próprios escolhidos, ou não entra.
  void addItems(List<PartyItem> items) {
    _ensureEditable();

    for (final item in items) {
      final spec = item.spec;
      spec.checkQuantity(item.quantity);
      spec.validate(item.configuration.values);
      if (spec.requiresEventDetails &&
          (eventDate == null || guestCount == null)) {
        throw const EventDetailsRequired();
      }
      if (item.pricing.model == PricingModel.perPerson && guestCount == null) {
        throw const GuestCountRequired();
      }
    }
    _checkCapacity(guestCount, items);

    budget = budget.add(items);
    _touch();
  }

  /// Troca a quantidade e a configuração de um item que já está na festa. O
  /// que foi copiado do catálogo (nome, preço) continua como entrou.
  void updateItem(
    PartyItemId id, {
    required Quantity quantity,
    required Map<String, Object?> configuration,
  }) {
    _ensureEditable();
    final item = budget.findById(id);
    if (item == null) throw const PartyItemNotFound();

    final spec = item.spec;
    spec.checkQuantity(quantity);
    final cleaned = spec.validate(configuration);
    if (quantity == item.quantity && cleaned == item.configuration) return;

    budget = budget.replace(
      item.copyWith(
        quantity: quantity,
        configuration: cleaned,
        // O valor informado pelo fornecedor era para a configuração anterior.
        quote: const ItemQuote.none(),
      ),
    );
    _touch();
  }

  /// Tira um item da festa e diz o que saiu ou ficou solto com ele.
  ItemRemoval removeItem(PartyItemId id) {
    _ensureEditable();
    final removal = budget.removalOf(id);

    final item = removal.item;
    if (item.relation.isRequired) {
      final parent = budget.findById(item.relation.parentId!);
      if (parent != null) {
        throw RequiredItemCannotLeaveAlone(
          item.nameSnapshot,
          parent.nameSnapshot,
        );
      }
    }

    budget = budget.remove(id);
    _touch();
    return removal;
  }

  // ---------------------------------------------------------------
  // O orçamento
  // ---------------------------------------------------------------

  /// Solicita o orçamento: congela o conteúdo e manda cada item para o
  /// fornecedor dele.
  void requestQuote() {
    if (status != PartyStatus.planning) {
      throw const InvalidPartyTransition(
        'Só uma festa em planejamento pode ter o orçamento solicitado.',
      );
    }
    final blockers = quoteBlockers;
    if (blockers.isNotEmpty) throw blockers.first;

    // Quem já deu o valor, e nada mudou para ele desde então, não precisa
    // responder de novo. Os outros recebem o pedido.
    budget = budget.withQuotes(
      (item) => item.quote.isQuoted ? item.quote : const ItemQuote.pending(),
    );
    quoteRound += 1;
    status = _statusFromQuotes();

    final now = _clock();
    final current = estimate;
    quoteSnapshot = QuoteRequestSnapshot(
      requestedAt: now,
      estimatedTotal: current.total,
      unpricedItems: current.unpricedItems,
    );
    _record(PartyHistoryKind.quoteRequested, amount: current.total);
    _touch();
  }

  /// Volta para o planejamento, para a pessoa poder alterar a festa. O que
  /// cada fornecedor já respondeu continua à vista.
  void reopenForEditing() {
    if (!status.isSubmitted) {
      throw const InvalidPartyTransition(
        'Só uma festa com o orçamento solicitado pode voltar para a edição.',
      );
    }
    // O pedido foi retirado: quem ainda não tinha respondido não responde mais.
    budget = budget.withQuotes(
      (item) => item.quote.status == QuoteStatus.pending
          ? const ItemQuote.none()
          : item.quote,
    );
    quoteSnapshot = null;
    status = PartyStatus.planning;
    _record(PartyHistoryKind.reopened);
    _touch();
  }

  /// A pessoa aceita o orçamento que recebeu.
  void confirmQuote() {
    if (status != PartyStatus.quoted) {
      throw const InvalidPartyTransition(
        'Só dá para aceitar o orçamento depois que todos os fornecedores '
        'responderem.',
      );
    }
    status = PartyStatus.confirmed;
    _record(PartyHistoryKind.confirmed, amount: quotedTotal);
    _touch();
  }

  void cancel() {
    if (status == PartyStatus.paid) {
      throw const InvalidPartyTransition(
        'Uma festa já paga não pode ser cancelada.',
      );
    }
    if (status == PartyStatus.cancelled) {
      throw const InvalidPartyTransition('Esta festa já está cancelada.');
    }
    quoteSnapshot = null;
    status = PartyStatus.cancelled;
    _record(PartyHistoryKind.cancelled);
    _touch();
  }

  /// Lança a regra que impede apagar a festa, se houver uma.
  void ensureCanBeDeleted() {
    if (status == PartyStatus.paid) throw const PaidPartyCannotBeDeleted();
    // O pedido chegou a fornecedores: some para eles só depois de um
    // cancelamento, que fica registrado.
    if (status.isSubmitted) throw const PartyHasOpenQuote();
  }

  // ---------------------------------------------------------------
  // A resposta do fornecedor
  // ---------------------------------------------------------------

  /// Registra o que o fornecedor de [itemId] respondeu e ajusta o status.
  ///
  /// Na API quem faz isso é o servidor (`apply_vendor_response`); aqui é o que
  /// o modo demonstração usa, com as mesmas regras.
  void registerVendorResponse(PartyItemId itemId, VendorResponse response) {
    if (!status.acceptsVendorAnswers) throw const QuoteRequestClosed();
    final item = budget.findById(itemId);
    if (item == null || item.quote.status == QuoteStatus.none) {
      throw const QuoteRequestClosed();
    }

    final message = _cleanMessage(response.message);
    final amount = response.amount;
    final PartyHistoryKind kind;
    switch (response.status) {
      case QuoteStatus.quoted:
        if (amount == null ||
            amount.isNegative ||
            amount.cents > VendorResponse.maxAmountCents) {
          throw const InvalidQuoteResponse('Informe o valor do orçamento.');
        }
        kind = PartyHistoryKind.vendorQuoted;
      case QuoteStatus.changesRequested || QuoteStatus.declined:
        if (message == null ||
            message.length < VendorResponse.minExplanationLength) {
          throw const InvalidQuoteResponse('Explique o motivo para o cliente.');
        }
        kind = response.status == QuoteStatus.changesRequested
            ? PartyHistoryKind.vendorRequestedChanges
            : PartyHistoryKind.vendorDeclined;
      case QuoteStatus.none || QuoteStatus.pending:
        throw const InvalidQuoteResponse('Resposta de orçamento inválida.');
    }

    final now = _clock();
    budget = budget.replace(
      item.copyWith(
        quote: ItemQuote(
          status: response.status,
          amount: response.status == QuoteStatus.quoted ? amount : null,
          message: message,
          respondedAt: now,
        ),
      ),
    );
    status = _statusFromQuotes();
    _history = List.unmodifiable([
      ..._history,
      PartyHistoryEntry(
        kind: kind,
        actor: PartyHistoryActor.vendor,
        round: quoteRound,
        at: now,
        itemId: item.id,
        itemName: item.nameSnapshot,
        message: message,
        amount: response.status == QuoteStatus.quoted ? amount : null,
      ),
    ]);
    updatedAt = now;
  }

  // ---------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------

  void _ensureEditable() {
    if (status.isEditable) return;
    if (status.isSubmitted) throw const PartyLockedMutationNotAllowed();
    throw InvalidPartyTransition(
      status == PartyStatus.paid
          ? 'Uma festa já paga não pode ser alterada.'
          : 'Uma festa cancelada não pode ser alterada.',
    );
  }

  /// O status de uma festa com o orçamento solicitado, pelo que cada item
  /// recebeu.
  PartyStatus _statusFromQuotes() {
    final items = budget.items;
    if (items.any((item) => item.quote.needsTheClient)) {
      return PartyStatus.editRequested;
    }
    if (items.isNotEmpty && items.every((item) => item.quote.isQuoted)) {
      return PartyStatus.quoted;
    }
    return PartyStatus.locked;
  }

  static void _checkCapacity(GuestCount? guests, List<PartyItem> items) {
    if (guests == null) return;
    for (final item in items) {
      final capacity = item.capacity;
      if (capacity != null && guests.value > capacity) {
        throw GuestCountExceedsCapacity(capacity);
      }
    }
  }

  static String? _cleanMessage(String? message) {
    final trimmed = message?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > VendorResponse.maxMessageLength) {
      throw const InvalidQuoteResponse(
        'A mensagem pode ter até ${VendorResponse.maxMessageLength} '
        'caracteres.',
      );
    }
    return trimmed;
  }

  void _record(PartyHistoryKind kind, {Money? amount}) {
    _history = List.unmodifiable([
      ..._history,
      PartyHistoryEntry(
        kind: kind,
        actor: PartyHistoryActor.client,
        round: quoteRound,
        at: _clock(),
        amount: amount,
      ),
    ]);
  }

  void _touch() => updatedAt = _clock();
}
