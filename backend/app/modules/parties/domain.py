"""Regras de negócio das festas, sem banco e sem HTTP.

Uma festa é a composição de um evento: os dados dele (tipo, data, convidados)
e os itens escolhidos, cada um configurado do jeito da sua categoria. O app
planeja a festa localmente e envia o estado que deseja gravar. O servidor é a
autoridade: ``reconcile`` compara o estado atual com o desejado e só aceita o
que as regras permitem. São as mesmas regras do agregado ``Party`` do app.

O que nunca vem do cliente:

- nome, categoria, preço, forma de cobrança e capacidade de um item novo, que
  são copiados do catálogo no momento em que ele entra;
- a relação de um item com outro (serviço do próprio anúncio, obrigatório ou
  recomendado), que é conferida no catálogo;
- o orçamento de cada item e os status que dependem dele: quem os muda é a
  resposta do fornecedor (``apply_vendor_response``).

Ciclo de vida, do lado do cliente::

    rascunho -> planejamento -> orçamento solicitado -> (o fornecedor responde)
                     ^                                          |
                     +------------- voltar a editar ------------+

    orçamento recebido -> confirmada        qualquer um, menos paga -> cancelada
"""

import uuid
from collections.abc import Callable, Mapping
from dataclasses import dataclass, field, replace
from datetime import datetime
from enum import StrEnum

from app.core.errors import ConflictError, UnprocessableError
from app.modules.catalog.pricing import PricingModel
from app.modules.catalog.pricing import estimate_cents as price_estimate
from app.modules.catalog.reference_data import VENUE_CATEGORY
from app.modules.parties.configuration import (
    DURATION,
    Configuration,
    spec_for,
    validate_item,
)

MAX_ITEMS_PER_PARTY = 50
# Teto do valor que um fornecedor informa para um item: R$ 10 milhões.
MAX_QUOTE_CENTS = 1_000_000_000
QUOTE_MESSAGE_MAX_LENGTH = 500
# Um pedido de alteração ou uma recusa sem explicação não ajuda quem recebe.
QUOTE_MESSAGE_MIN_LENGTH = 5


class PartyStatus(StrEnum):
    DRAFT = "draft"
    PLANNING = "planning"
    # Orçamento solicitado: esperando os fornecedores.
    LOCKED = "locked"
    # Orçamento recebido: todos os itens têm o valor do fornecedor.
    QUOTED = "quoted"
    # Edição solicitada: um fornecedor pediu uma alteração ou não pode atender.
    EDIT_REQUESTED = "edit_requested"
    # O cliente aceitou o orçamento recebido.
    CONFIRMED = "confirmed"
    PAID = "paid"
    CANCELLED = "cancelled"


class ItemRelation(StrEnum):
    INDEPENDENT = "independent"
    # Serviço do próprio anúncio a que o item está ligado: sai junto com ele.
    LINKED = "linked"
    # Serviço do próprio anúncio que é obrigatório: não sai sozinho.
    REQUIRED = "required"
    # Anúncio à parte, indicado por outro item: continua na festa sem ele.
    RECOMMENDED = "recommended"


class QuoteStatus(StrEnum):
    NONE = "none"
    PENDING = "pending"
    QUOTED = "quoted"
    CHANGES_REQUESTED = "changes_requested"
    DECLINED = "declined"


class HistoryKind(StrEnum):
    QUOTE_REQUESTED = "quote_requested"
    REOPENED = "reopened"
    VENDOR_QUOTED = "vendor_quoted"
    VENDOR_REQUESTED_CHANGES = "vendor_requested_changes"
    VENDOR_DECLINED = "vendor_declined"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"


class HistoryActor(StrEnum):
    CLIENT = "client"
    VENDOR = "vendor"


_EDITABLE = frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING})
# O orçamento foi pedido: o conteúdo fica congelado, e é esse conteúdo que os
# fornecedores veem.
SUBMITTED = frozenset(
    {PartyStatus.LOCKED, PartyStatus.QUOTED, PartyStatus.EDIT_REQUESTED, PartyStatus.CONFIRMED}
)
# Enquanto o cliente não aceita, o fornecedor pode responder ou corrigir a resposta.
ANSWERABLE = frozenset({PartyStatus.LOCKED, PartyStatus.QUOTED, PartyStatus.EDIT_REQUESTED})
_OWN_SERVICE = frozenset({ItemRelation.LINKED, ItemRelation.REQUIRED})
_NEEDS_THE_CLIENT = frozenset({QuoteStatus.CHANGES_REQUESTED, QuoteStatus.DECLINED})

# De cada estado atual (None = festa ainda não existe), para onde o cliente
# pode levar a festa. Três destinos nunca aparecem: "orçamento recebido" e
# "edição solicitada" saem da resposta do fornecedor, e "paga", do fluxo de
# pagamento, sempre no servidor.
_ALLOWED_TRANSITIONS: dict[PartyStatus | None, frozenset[PartyStatus]] = {
    None: frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING}),
    PartyStatus.DRAFT: frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING, PartyStatus.CANCELLED}),
    PartyStatus.PLANNING: frozenset(
        {PartyStatus.PLANNING, PartyStatus.LOCKED, PartyStatus.CANCELLED}
    ),
    PartyStatus.LOCKED: frozenset(
        {PartyStatus.LOCKED, PartyStatus.PLANNING, PartyStatus.CANCELLED}
    ),
    PartyStatus.QUOTED: frozenset(
        {
            PartyStatus.QUOTED,
            PartyStatus.PLANNING,
            PartyStatus.CONFIRMED,
            PartyStatus.CANCELLED,
        }
    ),
    PartyStatus.EDIT_REQUESTED: frozenset(
        {PartyStatus.EDIT_REQUESTED, PartyStatus.PLANNING, PartyStatus.CANCELLED}
    ),
    PartyStatus.CONFIRMED: frozenset(
        {PartyStatus.CONFIRMED, PartyStatus.PLANNING, PartyStatus.CANCELLED}
    ),
    PartyStatus.PAID: frozenset({PartyStatus.PAID}),
    PartyStatus.CANCELLED: frozenset({PartyStatus.CANCELLED}),
}


class InvalidPartyTransitionError(ConflictError):
    code = "invalid_party_transition"
    message = "Esta mudança de status não é permitida."


class PartyLockedError(ConflictError):
    code = "party_locked_mutation_not_allowed"
    message = "O orçamento desta festa já foi solicitado; volte a editar para poder alterar."


class VenueAlreadySelectedError(ConflictError):
    code = "venue_already_selected"
    message = "Já existe um salão selecionado nesta festa."


class CannotLockWithoutItemsError(ConflictError):
    code = "cannot_lock_without_items"
    message = "Adicione ao menos um item antes de solicitar o orçamento."


class ListingNotAvailableError(UnprocessableError):
    code = "listing_not_available"
    message = "Um dos itens não está mais disponível."


class DuplicatePartyItemError(UnprocessableError):
    code = "duplicate_party_item"
    message = "O mesmo item foi enviado mais de uma vez."


class TooManyPartyItemsError(UnprocessableError):
    code = "too_many_party_items"
    message = f"Uma festa pode ter no máximo {MAX_ITEMS_PER_PARTY} itens."


class CurrencyMismatchError(ConflictError):
    code = "currency_mismatch"
    message = "Todos os itens da festa precisam estar na mesma moeda."


class InvalidItemRelationError(UnprocessableError):
    code = "invalid_item_relation"
    message = "A ligação entre os itens da festa não é válida."


class ParentItemMissingError(ConflictError):
    code = "parent_item_missing"
    message = "Um serviço do próprio anunciante só fica na festa junto com o anúncio dele."


class RequiredItemMissingError(ConflictError):
    code = "required_item_missing"
    message = "Este anúncio só pode ser contratado com os serviços obrigatórios dele."


class GuestCountExceedsCapacityError(ConflictError):
    code = "guest_count_exceeds_capacity"

    def __init__(self, capacity: int) -> None:
        super().__init__(f"O espaço escolhido comporta até {capacity} pessoas.")


class EventDateInPastError(UnprocessableError):
    code = "event_date_in_past"
    message = "A data da festa precisa ser no futuro."


class EventDateRequiredError(ConflictError):
    code = "event_date_required"
    message = "Informe a data da festa antes de solicitar o orçamento."


class GuestCountRequiredError(ConflictError):
    code = "guest_count_required"
    message = "Informe o número de convidados da festa."


class EventDetailsRequiredError(ConflictError):
    code = "event_details_required"
    message = "Informe a data e o número de convidados da festa para escolher o salão."


class UnknownEventTypeError(UnprocessableError):
    code = "unknown_event_type"
    message = "Tipo de evento inválido."


class ItemNoLongerAvailableError(ConflictError):
    code = "item_no_longer_available"

    def __init__(self, name: str) -> None:
        super().__init__(
            f"{name} não está mais disponível. Remova o item para solicitar o orçamento."
        )


class QuoteRequestClosedError(ConflictError):
    code = "quote_request_closed"
    message = "Este pedido não está mais aberto para resposta."


class InvalidQuoteResponseError(UnprocessableError):
    code = "invalid_quote_response"
    message = "Resposta de orçamento inválida."


@dataclass(frozen=True)
class CatalogItem:
    """O que o catálogo informa sobre um anúncio ou um serviço próprio disponível."""

    # O anúncio. Para um serviço próprio, o anúncio a que ele pertence.
    listing_id: uuid.UUID
    category: str
    name: str
    unit_price_cents: int
    currency: str
    image_url: str | None
    pricing_model: PricingModel = PricingModel.FIXED
    minimum_cents: int | None = None
    capacity: int | None = None
    vendor_id: uuid.UUID | None = None
    # Preenchido quando é um serviço próprio; ``required`` só vale para ele.
    offer_id: uuid.UUID | None = None
    required: bool = False
    # Só de um anúncio: o que precisa vir junto e o que ele recomenda.
    required_offer_ids: frozenset[uuid.UUID] = frozenset()
    partner_listing_ids: frozenset[uuid.UUID] = frozenset()


CatalogLookup = Callable[[uuid.UUID], CatalogItem | None]


def _nothing(_id: uuid.UUID) -> CatalogItem | None:
    return None


@dataclass(frozen=True)
class Catalog:
    """O que as regras precisam saber de fora da festa, no momento da gravação."""

    listing: CatalogLookup
    offer: CatalogLookup = _nothing
    event_types: frozenset[str] = frozenset()


@dataclass(frozen=True)
class Quote:
    """A resposta do fornecedor a um item, e em que pé ela está."""

    status: QuoteStatus = QuoteStatus.NONE
    amount_cents: int | None = None
    message: str | None = None
    responded_at: datetime | None = None


NO_QUOTE = Quote()
_PENDING = Quote(status=QuoteStatus.PENDING)


@dataclass(frozen=True)
class ItemState:
    id: uuid.UUID
    # Um item vem de um anúncio ou de um serviço próprio, nunca dos dois. Os
    # dois nulos: a origem saiu do catálogo e ficou só a cópia.
    listing_id: uuid.UUID | None
    category: str
    name: str
    unit_price_cents: int
    currency: str
    quantity: int
    image_url: str | None
    offer_id: uuid.UUID | None = None
    vendor_id: uuid.UUID | None = None
    parent_item_id: uuid.UUID | None = None
    relation: ItemRelation = ItemRelation.INDEPENDENT
    pricing_model: PricingModel = PricingModel.FIXED
    minimum_cents: int | None = None
    capacity: int | None = None
    configuration: Configuration = field(default_factory=dict)
    quote: Quote = NO_QUOTE

    @property
    def is_own_service(self) -> bool:
        return self.relation in _OWN_SERVICE

    @property
    def has_source(self) -> bool:
        return self.listing_id is not None or self.offer_id is not None

    def estimate_cents(self, guest_count: int | None) -> int | None:
        """A estimativa deste item, ou ``None`` se não dá para estimar."""
        hours = self.configuration.get(DURATION)
        return price_estimate(
            self.pricing_model,
            self.unit_price_cents,
            minimum_cents=self.minimum_cents,
            guests=guest_count,
            hours=hours if isinstance(hours, int) else None,
            quantity=self.quantity,
        )


@dataclass(frozen=True)
class PartyState:
    title: str
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    items: tuple[ItemState, ...]
    event_type: str | None = None
    # Quantas vezes o orçamento foi solicitado.
    quote_round: int = 0

    @property
    def estimate_cents(self) -> int:
        """A soma do que dá para estimar. Veja ``unpriced_items`` para o resto."""
        return sum(item.estimate_cents(self.guest_count) or 0 for item in self.items)

    @property
    def unpriced_items(self) -> int:
        """Quantos itens ficaram fora da estimativa (sob consulta, ou sem medida)."""
        return sum(1 for item in self.items if item.estimate_cents(self.guest_count) is None)

    @property
    def quoted_cents(self) -> int | None:
        """A soma dos valores informados pelos fornecedores, se algum respondeu."""
        amounts = [
            item.quote.amount_cents
            for item in self.items
            if item.quote.status is QuoteStatus.QUOTED and item.quote.amount_cents is not None
        ]
        return sum(amounts) if amounts else None


@dataclass(frozen=True)
class DesiredItem:
    id: uuid.UUID
    listing_id: uuid.UUID | None
    quantity: int
    offer_id: uuid.UUID | None = None
    parent_item_id: uuid.UUID | None = None
    configuration: Mapping[str, object] = field(default_factory=dict)


@dataclass(frozen=True)
class DesiredParty:
    title: str
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    items: tuple[DesiredItem, ...]
    event_type: str | None = None


@dataclass(frozen=True)
class HistoryEntry:
    """Um acontecimento da festa que fica registrado para sempre."""

    kind: HistoryKind
    actor: HistoryActor
    round: int
    item_id: uuid.UUID | None = None
    item_name: str | None = None
    message: str | None = None
    amount_cents: int | None = None


@dataclass(frozen=True)
class VendorResponse:
    status: QuoteStatus
    amount_cents: int | None = None
    message: str | None = None


# ----------------------------------------------------------------------
# O que o cliente pede
# ----------------------------------------------------------------------


def reconcile(
    current: PartyState | None,
    desired: DesiredParty,
    *,
    catalog: Catalog,
    now: datetime,
) -> PartyState:
    """Devolve o novo estado da festa ou levanta o erro da regra violada."""
    current_status = current.status if current is not None else None
    if desired.status not in _ALLOWED_TRANSITIONS[current_status]:
        raise InvalidPartyTransitionError

    if current is not None and current.status not in _EDITABLE:
        if _content_changed(current, desired):
            if current.status in SUBMITTED:
                raise PartyLockedError
            raise InvalidPartyTransitionError("Esta festa não pode mais ser alterada.")
        # Só o status muda (voltar a editar, aceitar ou cancelar).
        return _with_status(current, desired.status)

    event_changed = current is not None and _event_of(current) != _event_of(desired)
    _check_event(current, desired, catalog=catalog, now=now)

    items = _reconcile_items(
        current.items if current is not None else (),
        desired,
        catalog,
        # Mudou a data ou o número de convidados: o valor que cada fornecedor
        # informou valia para o evento de antes.
        discard_quotes=event_changed,
    )
    state = PartyState(
        title=desired.title,
        event_type=desired.event_type,
        event_at=desired.event_at,
        guest_count=desired.guest_count,
        status=desired.status,
        quote_round=current.quote_round if current is not None else 0,
        items=items,
    )
    if desired.status is PartyStatus.LOCKED:
        return _request_quote(state, catalog=catalog, now=now)
    return state


def describe_transition(current: PartyState | None, new: PartyState) -> HistoryEntry | None:
    """O que a gravação pedida pelo cliente deixa registrado no histórico."""
    previous = current.status if current is not None else None
    if new.status == previous:
        return None

    kind: HistoryKind
    amount: int | None = None
    if previous in _EDITABLE and new.status in SUBMITTED:
        kind, amount = HistoryKind.QUOTE_REQUESTED, new.estimate_cents
    elif previous in SUBMITTED and new.status is PartyStatus.PLANNING:
        kind = HistoryKind.REOPENED
    elif new.status is PartyStatus.CONFIRMED:
        kind, amount = HistoryKind.CONFIRMED, new.quoted_cents
    elif new.status is PartyStatus.CANCELLED:
        kind = HistoryKind.CANCELLED
    else:
        # Rascunho -> planejamento: não é um acontecimento para quem acompanha.
        return None
    return HistoryEntry(
        kind=kind, actor=HistoryActor.CLIENT, round=new.quote_round, amount_cents=amount
    )


# ----------------------------------------------------------------------
# O que o fornecedor responde
# ----------------------------------------------------------------------


def apply_vendor_response(
    state: PartyState,
    item_id: uuid.UUID,
    response: VendorResponse,
    *,
    now: datetime,
) -> tuple[PartyState, HistoryEntry]:
    """Registra a resposta de um fornecedor a um item e ajusta o status da festa.

    Quem chama já conferiu que o item é mesmo deste fornecedor.
    """
    if state.status not in ANSWERABLE:
        raise QuoteRequestClosedError
    item = next((candidate for candidate in state.items if candidate.id == item_id), None)
    if item is None or item.quote.status is QuoteStatus.NONE:
        raise QuoteRequestClosedError

    message = (response.message or "").strip() or None
    if message is not None and len(message) > QUOTE_MESSAGE_MAX_LENGTH:
        raise InvalidQuoteResponseError(
            f"A mensagem pode ter até {QUOTE_MESSAGE_MAX_LENGTH} caracteres."
        )

    kind: HistoryKind
    amount: int | None = None
    match response.status:
        case QuoteStatus.QUOTED:
            amount = response.amount_cents
            if amount is None or not 0 <= amount <= MAX_QUOTE_CENTS:
                raise InvalidQuoteResponseError("Informe o valor do orçamento.")
            kind = HistoryKind.VENDOR_QUOTED
        case QuoteStatus.CHANGES_REQUESTED | QuoteStatus.DECLINED:
            if message is None or len(message) < QUOTE_MESSAGE_MIN_LENGTH:
                raise InvalidQuoteResponseError("Explique o motivo para o cliente.")
            kind = (
                HistoryKind.VENDOR_REQUESTED_CHANGES
                if response.status is QuoteStatus.CHANGES_REQUESTED
                else HistoryKind.VENDOR_DECLINED
            )
        case _:
            raise InvalidQuoteResponseError

    answered = replace(
        item,
        quote=Quote(status=response.status, amount_cents=amount, message=message, responded_at=now),
    )
    items = tuple(answered if candidate.id == item_id else candidate for candidate in state.items)
    entry = HistoryEntry(
        kind=kind,
        actor=HistoryActor.VENDOR,
        round=state.quote_round,
        item_id=item.id,
        item_name=item.name,
        message=message,
        amount_cents=amount,
    )
    return replace(state, items=items, status=_status_from_quotes(items)), entry


# ----------------------------------------------------------------------
# Internos
# ----------------------------------------------------------------------


def _event_of(party: PartyState | DesiredParty) -> tuple[str | None, datetime | None, int | None]:
    """O que um fornecedor considera para dar o preço: tipo, data e convidados."""
    return party.event_type, party.event_at, party.guest_count


def _content_changed(current: PartyState, desired: DesiredParty) -> bool:
    if desired.title != current.title or _event_of(desired) != _event_of(current):
        return True
    if len(desired.items) != len(current.items):
        return True
    wanted = {item.id: item for item in desired.items}
    for item in current.items:
        other = wanted.get(item.id)
        if (
            other is None
            or other.quantity != item.quantity
            or other.parent_item_id != item.parent_item_id
            or dict(other.configuration) != dict(item.configuration)
        ):
            return True
    return False


def _with_status(current: PartyState, status: PartyStatus) -> PartyState:
    if status is current.status:
        return current
    items = current.items
    if status is PartyStatus.PLANNING:
        # O pedido foi retirado: quem ainda não tinha respondido não responde
        # mais. O que já veio (valor, pedido de alteração) fica à vista.
        items = tuple(
            replace(item, quote=NO_QUOTE) if item.quote.status is QuoteStatus.PENDING else item
            for item in items
        )
    return replace(current, status=status, items=items)


def _check_event(
    current: PartyState | None, desired: DesiredParty, *, catalog: Catalog, now: datetime
) -> None:
    previous_type = current.event_type if current is not None else None
    if (
        desired.event_type is not None
        and desired.event_type != previous_type
        and desired.event_type not in catalog.event_types
    ):
        raise UnknownEventTypeError

    previous_date = current.event_at if current is not None else None
    # Só a data que está sendo informada agora: uma festa antiga, cuja data já
    # passou, continua podendo ser aberta e editada.
    if (
        desired.event_at is not None
        and desired.event_at != previous_date
        and desired.event_at <= now
    ):
        raise EventDateInPastError


def _request_quote(state: PartyState, *, catalog: Catalog, now: datetime) -> PartyState:
    if not state.items:
        raise CannotLockWithoutItemsError
    if state.event_at is None:
        raise EventDateRequiredError
    if state.event_at <= now:
        raise EventDateInPastError
    if state.guest_count is None:
        raise GuestCountRequiredError
    for item in state.items:
        if not _still_available(item, catalog):
            raise ItemNoLongerAvailableError(item.name)

    # Quem já deu o valor, e nada mudou para ele desde então, não precisa
    # responder de novo. Os outros recebem o pedido.
    items = tuple(
        item if item.quote.status is QuoteStatus.QUOTED else replace(item, quote=_PENDING)
        for item in state.items
    )
    return replace(
        state, items=items, status=_status_from_quotes(items), quote_round=state.quote_round + 1
    )


def _still_available(item: ItemState, catalog: Catalog) -> bool:
    if item.offer_id is not None:
        return catalog.offer(item.offer_id) is not None
    if item.listing_id is not None:
        return catalog.listing(item.listing_id) is not None
    return False


def _status_from_quotes(items: tuple[ItemState, ...]) -> PartyStatus:
    """O status de uma festa com orçamento solicitado, pelo que cada item recebeu."""
    statuses = {item.quote.status for item in items}
    if statuses & _NEEDS_THE_CLIENT:
        return PartyStatus.EDIT_REQUESTED
    if statuses == {QuoteStatus.QUOTED}:
        return PartyStatus.QUOTED
    return PartyStatus.LOCKED


def _reconcile_items(
    current: tuple[ItemState, ...],
    desired: DesiredParty,
    catalog: Catalog,
    *,
    discard_quotes: bool,
) -> tuple[ItemState, ...]:
    if len(desired.items) > MAX_ITEMS_PER_PARTY:
        raise TooManyPartyItemsError

    existing = {item.id: item for item in current}
    # O que o catálogo disse de cada item que está entrando agora.
    entering: dict[uuid.UUID, CatalogItem] = {}
    seen_ids: set[uuid.UUID] = set()
    seen_sources: set[uuid.UUID] = set()
    result: list[ItemState] = []

    for wanted in desired.items:
        if wanted.id in seen_ids:
            raise DuplicatePartyItemError
        seen_ids.add(wanted.id)

        known = existing.get(wanted.id)
        if known is not None:
            item = _updated_item(known, wanted)
        else:
            entry = _catalog_entry(wanted, catalog)
            entering[wanted.id] = entry
            item = _new_item(wanted, entry)
        if discard_quotes:
            item = replace(item, quote=NO_QUOTE)

        source = item.offer_id or item.listing_id
        if source is not None:
            if source in seen_sources:
                raise DuplicatePartyItemError
            seen_sources.add(source)
        result.append(item)

    items = _check_relations(result, existing, entering, catalog)
    _check_event_requirements(items, entering, desired)

    if sum(1 for item in items if item.category == VENUE_CATEGORY) > 1:
        raise VenueAlreadySelectedError
    if len({item.currency for item in items}) > 1:
        raise CurrencyMismatchError
    if desired.guest_count is not None:
        for item in items:
            if item.capacity is not None and desired.guest_count > item.capacity:
                raise GuestCountExceedsCapacityError(item.capacity)

    return items


def _updated_item(known: ItemState, wanted: DesiredItem) -> ItemState:
    """Um item que já estava na festa: mantém o que foi copiado do catálogo.

    Só a quantidade e a configuração mudam; a ligação com outro item, só para
    soltar um item recomendado.
    """
    quantity, configuration = known.quantity, known.configuration
    # O que não mudou não é validado de novo: um item gravado antes de uma
    # regra existir continua podendo ficar na festa como está.
    if wanted.quantity != quantity or dict(wanted.configuration) != dict(configuration):
        spec = spec_for(known.category, known.pricing_model, is_own_service=known.is_own_service)
        configuration = validate_item(
            spec, quantity=wanted.quantity, configuration=wanted.configuration
        )
        quantity = wanted.quantity

    relation, parent = known.relation, known.parent_item_id
    if wanted.parent_item_id != parent:
        if wanted.parent_item_id is not None or relation is not ItemRelation.RECOMMENDED:
            raise InvalidItemRelationError
        relation, parent = ItemRelation.INDEPENDENT, None

    changed = quantity != known.quantity or dict(configuration) != dict(known.configuration)
    return replace(
        known,
        quantity=quantity,
        configuration=configuration,
        relation=relation,
        parent_item_id=parent,
        # O valor informado pelo fornecedor era para a configuração anterior.
        quote=NO_QUOTE if changed else known.quote,
    )


def _catalog_entry(wanted: DesiredItem, catalog: Catalog) -> CatalogItem:
    if (wanted.listing_id is None) == (wanted.offer_id is None):
        raise ListingNotAvailableError
    entry = (
        catalog.offer(wanted.offer_id)
        if wanted.offer_id is not None
        else catalog.listing(wanted.listing_id)  # type: ignore[arg-type]
    )
    if entry is None:
        raise ListingNotAvailableError
    return entry


def _new_item(wanted: DesiredItem, entry: CatalogItem) -> ItemState:
    is_own_service = entry.offer_id is not None
    if is_own_service:
        if wanted.parent_item_id is None:
            raise ParentItemMissingError
        relation = ItemRelation.REQUIRED if entry.required else ItemRelation.LINKED
    elif wanted.parent_item_id is not None:
        relation = ItemRelation.RECOMMENDED
    else:
        relation = ItemRelation.INDEPENDENT

    spec = spec_for(entry.category, entry.pricing_model, is_own_service=is_own_service)
    configuration = validate_item(
        spec, quantity=wanted.quantity, configuration=wanted.configuration
    )
    return ItemState(
        id=wanted.id,
        listing_id=None if is_own_service else entry.listing_id,
        offer_id=entry.offer_id,
        vendor_id=entry.vendor_id,
        parent_item_id=wanted.parent_item_id,
        relation=relation,
        category=entry.category,
        name=entry.name,
        pricing_model=entry.pricing_model,
        unit_price_cents=entry.unit_price_cents,
        minimum_cents=entry.minimum_cents,
        currency=entry.currency,
        quantity=wanted.quantity,
        configuration=configuration,
        capacity=entry.capacity,
        image_url=entry.image_url,
    )


def _check_relations(
    items: list[ItemState],
    existing: Mapping[uuid.UUID, ItemState],
    entering: Mapping[uuid.UUID, CatalogItem],
    catalog: Catalog,
) -> tuple[ItemState, ...]:
    by_id = {item.id: item for item in items}
    checked: list[ItemState] = []

    for item in items:
        parent = by_id.get(item.parent_item_id) if item.parent_item_id is not None else None
        if parent is None:
            if item.relation in _OWN_SERVICE:
                raise ParentItemMissingError
            if item.relation is ItemRelation.RECOMMENDED:
                # Quem recomendou saiu da festa: o item fica, por conta própria.
                item = replace(item, relation=ItemRelation.INDEPENDENT, parent_item_id=None)
            checked.append(item)
            continue

        # Sem cadeias: um item ligado a outro não tem itens ligados a ele.
        if parent.id == item.id or parent.parent_item_id is not None:
            raise InvalidItemRelationError

        entry = entering.get(item.id)
        if entry is not None:
            # Item novo: a ligação que o cliente declarou é conferida no catálogo.
            if entry.offer_id is not None:
                if parent.listing_id != entry.listing_id:
                    raise InvalidItemRelationError
            else:
                parent_entry = entering.get(parent.id) or (
                    catalog.listing(parent.listing_id) if parent.listing_id else None
                )
                if parent_entry is None or entry.listing_id not in parent_entry.partner_listing_ids:
                    raise InvalidItemRelationError
        checked.append(item)

    for item_id, entry in entering.items():
        if entry.offer_id is None and entry.required_offer_ids:
            brought = {child.offer_id for child in checked if child.parent_item_id == item_id}
            if not entry.required_offer_ids <= brought:
                raise RequiredItemMissingError
    for old in existing.values():
        if (
            old.relation is ItemRelation.REQUIRED
            and old.id not in by_id
            and old.parent_item_id in by_id
        ):
            raise RequiredItemMissingError

    return tuple(checked)


def _check_event_requirements(
    items: tuple[ItemState, ...],
    entering: Mapping[uuid.UUID, CatalogItem],
    desired: DesiredParty,
) -> None:
    """O que o evento precisa ter informado para os itens fazerem sentido.

    Vale para os itens que estão entrando: quem já estava na festa não é
    barrado por um dado que ninguém pedia quando ele entrou.
    """
    for item in items:
        if item.id not in entering:
            continue
        spec = spec_for(item.category, item.pricing_model, is_own_service=item.is_own_service)
        if spec.requires_event_details and (
            desired.event_at is None or desired.guest_count is None
        ):
            raise EventDetailsRequiredError
        if item.pricing_model is PricingModel.PER_PERSON and desired.guest_count is None:
            raise GuestCountRequiredError
