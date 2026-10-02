"""Regras de negócio das festas, sem banco e sem HTTP.

O app planeja a festa localmente e envia o estado que deseja gravar. O servidor
é a autoridade: ``reconcile`` compara o estado atual com o desejado e só aceita
o que as regras permitem. São as mesmas regras do agregado ``Party`` do app:

- ciclo de vida: rascunho -> planejamento -> travada (orçamento solicitado);
  travada pode voltar ao planejamento; tudo menos "paga" pode ser cancelado;
- conteúdo (título, data, convidados, itens) só muda em rascunho/planejamento;
- no máximo um salão por festa;
- travar exige ao menos um item.

Nome, categoria e preço de um item novo nunca vêm do cliente: são copiados do
anúncio no catálogo no momento em que o item entra.
"""

import uuid
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum

from app.core.errors import ConflictError, UnprocessableError
from app.modules.catalog.reference_data import VENUE_CATEGORY

MAX_ITEMS_PER_PARTY = 50
MAX_ITEM_QUANTITY = 999


class PartyStatus(StrEnum):
    DRAFT = "draft"
    PLANNING = "planning"
    LOCKED = "locked"
    PAID = "paid"
    CANCELLED = "cancelled"


_EDITABLE = frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING})

# De cada estado atual (None = festa ainda não existe), para onde o cliente
# pode levar a festa. "Paga" não aparece como destino: só o fluxo de pagamento,
# no servidor, poderá marcar uma festa como paga.
_ALLOWED_TRANSITIONS: dict[PartyStatus | None, frozenset[PartyStatus]] = {
    None: frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING}),
    PartyStatus.DRAFT: frozenset({PartyStatus.DRAFT, PartyStatus.PLANNING, PartyStatus.CANCELLED}),
    PartyStatus.PLANNING: frozenset(
        {PartyStatus.PLANNING, PartyStatus.LOCKED, PartyStatus.CANCELLED}
    ),
    PartyStatus.LOCKED: frozenset(
        {PartyStatus.LOCKED, PartyStatus.PLANNING, PartyStatus.CANCELLED}
    ),
    PartyStatus.PAID: frozenset({PartyStatus.PAID}),
    PartyStatus.CANCELLED: frozenset({PartyStatus.CANCELLED}),
}


class InvalidPartyTransitionError(ConflictError):
    code = "invalid_party_transition"
    message = "Esta mudança de status não é permitida."


class PartyLockedError(ConflictError):
    code = "party_locked_mutation_not_allowed"
    message = "A festa está travada; destrave para poder alterar."


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


@dataclass(frozen=True)
class CatalogItem:
    """O que o catálogo informa sobre um anúncio disponível."""

    listing_id: uuid.UUID
    category: str
    name: str
    unit_price_cents: int
    currency: str
    image_url: str | None


@dataclass(frozen=True)
class ItemState:
    id: uuid.UUID
    listing_id: uuid.UUID | None
    category: str
    name: str
    unit_price_cents: int
    currency: str
    quantity: int
    image_url: str | None

    @property
    def subtotal_cents(self) -> int:
        return self.unit_price_cents * self.quantity


@dataclass(frozen=True)
class PartyState:
    title: str
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    items: tuple[ItemState, ...]

    @property
    def total_cents(self) -> int:
        return sum(item.subtotal_cents for item in self.items)


@dataclass(frozen=True)
class DesiredItem:
    id: uuid.UUID
    listing_id: uuid.UUID | None
    quantity: int


@dataclass(frozen=True)
class DesiredParty:
    title: str
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    items: tuple[DesiredItem, ...]


CatalogLookup = Callable[[uuid.UUID], CatalogItem | None]


def reconcile(
    current: PartyState | None,
    desired: DesiredParty,
    *,
    lookup: CatalogLookup,
) -> PartyState:
    """Devolve o novo estado da festa ou levanta o erro da regra violada."""
    current_status = current.status if current is not None else None
    if desired.status not in _ALLOWED_TRANSITIONS[current_status]:
        raise InvalidPartyTransitionError

    if current is not None and current.status not in _EDITABLE:
        if _content_changed(current, desired):
            if current.status is PartyStatus.LOCKED:
                raise PartyLockedError
            raise InvalidPartyTransitionError("Esta festa não pode mais ser alterada.")
        # Só o status muda (destravar ou cancelar); o conteúdo fica como está.
        return PartyState(
            title=current.title,
            event_at=current.event_at,
            guest_count=current.guest_count,
            status=desired.status,
            items=current.items,
        )

    items = _reconcile_items(current.items if current is not None else (), desired.items, lookup)
    if desired.status is PartyStatus.LOCKED and not items:
        raise CannotLockWithoutItemsError

    return PartyState(
        title=desired.title,
        event_at=desired.event_at,
        guest_count=desired.guest_count,
        status=desired.status,
        items=items,
    )


def _content_changed(current: PartyState, desired: DesiredParty) -> bool:
    if (
        desired.title != current.title
        or desired.event_at != current.event_at
        or desired.guest_count != current.guest_count
    ):
        return True
    current_items = {item.id: item.quantity for item in current.items}
    desired_items = {item.id: item.quantity for item in desired.items}
    return current_items != desired_items or len(desired.items) != len(desired_items)


def _reconcile_items(
    current: tuple[ItemState, ...],
    desired: tuple[DesiredItem, ...],
    lookup: CatalogLookup,
) -> tuple[ItemState, ...]:
    if len(desired) > MAX_ITEMS_PER_PARTY:
        raise TooManyPartyItemsError

    existing = {item.id: item for item in current}
    seen_ids: set[uuid.UUID] = set()
    seen_listings: set[uuid.UUID] = set()
    result: list[ItemState] = []

    for wanted in desired:
        if wanted.id in seen_ids:
            raise DuplicatePartyItemError
        seen_ids.add(wanted.id)

        known = existing.get(wanted.id)
        if known is not None:
            # Item que já estava na festa: mantém o que foi copiado do anúncio
            # quando ele entrou; só a quantidade pode mudar.
            item = ItemState(
                id=known.id,
                listing_id=known.listing_id,
                category=known.category,
                name=known.name,
                unit_price_cents=known.unit_price_cents,
                currency=known.currency,
                quantity=wanted.quantity,
                image_url=known.image_url,
            )
        else:
            if wanted.listing_id is None:
                raise ListingNotAvailableError
            catalog_item = lookup(wanted.listing_id)
            if catalog_item is None:
                raise ListingNotAvailableError
            item = ItemState(
                id=wanted.id,
                listing_id=catalog_item.listing_id,
                category=catalog_item.category,
                name=catalog_item.name,
                unit_price_cents=catalog_item.unit_price_cents,
                currency=catalog_item.currency,
                quantity=wanted.quantity,
                image_url=catalog_item.image_url,
            )

        if item.listing_id is not None:
            if item.listing_id in seen_listings:
                raise DuplicatePartyItemError
            seen_listings.add(item.listing_id)
        result.append(item)

    if sum(1 for item in result if item.category == VENUE_CATEGORY) > 1:
        raise VenueAlreadySelectedError
    if len({item.currency for item in result}) > 1:
        raise CurrencyMismatchError

    return tuple(result)
