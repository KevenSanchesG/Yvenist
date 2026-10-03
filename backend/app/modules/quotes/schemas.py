import uuid
from datetime import datetime
from typing import Annotated, Any, Self

from pydantic import AfterValidator, BaseModel, Field

from app.modules.catalog.pricing import PricingModel, public_price
from app.modules.parties.domain import (
    MAX_QUOTE_CENTS,
    QUOTE_MESSAGE_MAX_LENGTH,
    QUOTE_MESSAGE_MIN_LENGTH,
    ItemRelation,
    PartyStatus,
)
from app.modules.parties.mapping import item_state
from app.modules.parties.schemas import QuoteResponse
from app.modules.quotes.service import QuoteRequest


def _optional_message(value: str | None) -> str | None:
    return (value.strip() or None) if value is not None else None


def _explanation(value: str) -> str:
    cleaned = value.strip()
    if len(cleaned) < QUOTE_MESSAGE_MIN_LENGTH:
        raise ValueError("Explique o motivo para o cliente.")
    return cleaned


class QuoteAmountInput(BaseModel):
    """O valor que o fornecedor cobra pelo item, como o cliente o configurou."""

    amount_cents: int = Field(ge=0, le=MAX_QUOTE_CENTS)
    message: Annotated[
        str | None,
        Field(max_length=QUOTE_MESSAGE_MAX_LENGTH),
        AfterValidator(_optional_message),
    ] = None


class QuoteExplanationInput(BaseModel):
    """O motivo de um pedido de alteração ou de uma recusa."""

    message: Annotated[
        str, Field(max_length=QUOTE_MESSAGE_MAX_LENGTH), AfterValidator(_explanation)
    ]


class QuoteRequestResponse(BaseModel):
    """Um pedido de orçamento, como o fornecedor o vê.

    Sem o nome da festa nem nada de quem pediu: só o que é preciso para dar o
    preço.
    """

    item_id: uuid.UUID
    # Agrupa os itens do mesmo evento. Não dá acesso à festa.
    party_id: uuid.UUID
    party_status: PartyStatus
    quote_round: int
    updated_at: datetime
    event_type: str | None
    event_at: datetime | None
    guest_count: int | None
    listing_id: uuid.UUID | None
    offer_id: uuid.UUID | None
    relation: ItemRelation
    parent_name: str | None
    category: str
    name: str
    pricing_model: PricingModel
    unit_price_cents: int | None
    minimum_cents: int | None
    currency: str
    quantity: int
    configuration: dict[str, Any]
    estimate_cents: int | None
    quote: QuoteResponse
    # Falso quando o cliente já aceitou ou cancelou: a resposta não muda mais.
    can_respond: bool

    @classmethod
    def from_request(cls, request: QuoteRequest) -> Self:
        item, party = request.item, request.party
        return cls(
            item_id=item.id,
            party_id=party.id,
            party_status=party.status,
            quote_round=party.quote_round,
            updated_at=party.updated_at,
            event_type=party.event_type,
            event_at=party.event_at,
            guest_count=party.guest_count,
            listing_id=item.listing_id,
            offer_id=item.offer_id,
            relation=item.relation,
            parent_name=request.parent_name,
            category=item.category,
            name=item.name,
            pricing_model=item.pricing_model,
            unit_price_cents=public_price(item.pricing_model, item.unit_price_cents),
            minimum_cents=item.minimum_cents,
            currency=item.currency,
            quantity=item.quantity,
            configuration=dict(item.configuration),
            estimate_cents=item_state(item).estimate_cents(party.guest_count),
            quote=QuoteResponse.from_item(item),
            can_respond=request.can_respond,
        )


class QuoteRequestsResponse(BaseModel):
    items: list[QuoteRequestResponse]
