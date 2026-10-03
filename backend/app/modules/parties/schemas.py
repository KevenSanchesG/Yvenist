import uuid
from datetime import UTC, datetime
from typing import Annotated, Any, Self

from pydantic import AfterValidator, AwareDatetime, BaseModel, Field, StrictInt, StrictStr

from app.modules.catalog.pricing import PricingModel, public_price
from app.modules.parties.configuration import MAX_ITEM_QUANTITY
from app.modules.parties.domain import (
    MAX_ITEMS_PER_PARTY,
    DesiredItem,
    DesiredParty,
    HistoryActor,
    HistoryKind,
    ItemRelation,
    PartyStatus,
    QuoteStatus,
)
from app.modules.parties.mapping import to_state
from app.modules.parties.models import Party, PartyEvent, PartyItem, PartySnapshot

# Folga sobre o que qualquer categoria usa: a regra de cada campo está em
# ``configuration.py``; aqui só se impede um corpo desproporcional.
_MAX_CONFIGURATION_FIELDS = 20
_MAX_CONFIGURATION_TEXT = 1000

ConfigurationValue = StrictInt | Annotated[StrictStr, Field(max_length=_MAX_CONFIGURATION_TEXT)]


def _clean_title(value: str) -> str:
    cleaned = " ".join(value.split())
    if not cleaned:
        raise ValueError("O nome da festa não pode ficar vazio.")
    return cleaned


class PartyItemInput(BaseModel):
    id: uuid.UUID
    # De onde o item vem: um anúncio ou um serviço próprio de um anúncio.
    # Obrigatório para item novo; ignorado para item que já está na festa.
    listing_id: uuid.UUID | None = None
    offer_id: uuid.UUID | None = None
    # O item da mesma festa a que este está ligado: o anúncio de um serviço
    # próprio, ou quem recomendou um parceiro.
    parent_item_id: uuid.UUID | None = None
    quantity: int = Field(default=1, ge=1, le=MAX_ITEM_QUANTITY)
    configuration: dict[str, ConfigurationValue] = Field(
        default_factory=dict, max_length=_MAX_CONFIGURATION_FIELDS
    )


class PartyInput(BaseModel):
    """Estado que o cliente quer gravar para a festa."""

    title: Annotated[str, Field(max_length=80), AfterValidator(_clean_title)]
    event_type: Annotated[str | None, Field(max_length=40)] = None
    event_at: AwareDatetime | None = None
    guest_count: int | None = Field(default=None, ge=1, le=100_000)
    status: PartyStatus
    items: list[PartyItemInput] = Field(default_factory=list, max_length=MAX_ITEMS_PER_PARTY)
    # Versão que o cliente conhece (0 ou ausente ao criar). Se outra alteração
    # tiver sido gravada nesse meio tempo, a resposta é 409.
    version: int | None = Field(default=None, ge=0)

    def listing_ids(self) -> list[uuid.UUID]:
        return [item.listing_id for item in self.items if item.listing_id is not None]

    def offer_ids(self) -> list[uuid.UUID]:
        return [item.offer_id for item in self.items if item.offer_id is not None]

    def to_desired(self) -> DesiredParty:
        return DesiredParty(
            title=self.title,
            event_type=self.event_type,
            # Sempre em UTC: é assim que o banco guarda e que a API responde.
            event_at=self.event_at.astimezone(UTC) if self.event_at else None,
            guest_count=self.guest_count,
            status=self.status,
            items=tuple(
                DesiredItem(
                    id=item.id,
                    listing_id=item.listing_id,
                    offer_id=item.offer_id,
                    parent_item_id=item.parent_item_id,
                    quantity=item.quantity,
                    configuration=item.configuration,
                )
                for item in self.items
            ),
        )


class QuoteResponse(BaseModel):
    """O que o fornecedor respondeu sobre um item."""

    status: QuoteStatus
    amount_cents: int | None
    message: str | None
    responded_at: datetime | None

    @classmethod
    def from_item(cls, item: PartyItem) -> Self:
        return cls(
            status=item.quote_status,
            amount_cents=item.quoted_cents,
            message=item.quote_message,
            responded_at=item.quote_responded_at,
        )


class PartyItemResponse(BaseModel):
    id: uuid.UUID
    listing_id: uuid.UUID | None
    offer_id: uuid.UUID | None
    # Itens do mesmo fornecedor têm o mesmo valor aqui. Não identifica ninguém.
    vendor_id: uuid.UUID | None
    parent_item_id: uuid.UUID | None
    relation: ItemRelation
    category: str
    name: str
    pricing_model: PricingModel
    # Nulo quando o item é sob consulta.
    unit_price_cents: int | None
    minimum_cents: int | None
    currency: str
    quantity: int
    configuration: dict[str, Any]
    capacity: int | None
    image_url: str | None
    # Nulo quando não dá para estimar (sob consulta, ou falta uma medida).
    estimate_cents: int | None
    quote: QuoteResponse


class SnapshotLine(BaseModel):
    listing_id: uuid.UUID | None
    offer_id: uuid.UUID | None = None
    category: str
    name: str
    # Um retrato gravado antes de existirem modelos de preço somava preço
    # vezes quantidade: é o que "por unidade" quer dizer.
    pricing_model: PricingModel = PricingModel.PER_UNIT
    unit_price_cents: int
    quantity: int
    subtotal_cents: int | None


class PartySnapshotResponse(BaseModel):
    generated_at: datetime
    expires_at: datetime | None
    total_cents: int
    currency: str
    breakdown: list[SnapshotLine]

    @classmethod
    def from_snapshot(cls, snapshot: PartySnapshot) -> Self:
        return cls(
            generated_at=snapshot.generated_at,
            expires_at=snapshot.expires_at,
            total_cents=snapshot.total_cents,
            currency=snapshot.currency,
            breakdown=[SnapshotLine.model_validate(line) for line in snapshot.breakdown],
        )


class HistoryEntryResponse(BaseModel):
    kind: HistoryKind
    actor: HistoryActor
    quote_round: int
    item_id: uuid.UUID | None
    item_name: str | None
    message: str | None
    amount_cents: int | None
    created_at: datetime

    @classmethod
    def from_event(cls, event: PartyEvent) -> Self:
        return cls(
            kind=event.kind,
            actor=event.actor,
            quote_round=event.quote_round,
            item_id=event.item_id,
            item_name=event.item_name,
            message=event.message,
            amount_cents=event.amount_cents,
            created_at=event.created_at,
        )


class PartyResponse(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID
    title: str
    event_type: str | None
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    quote_round: int
    version: int
    items: list[PartyItemResponse]
    # A soma do que dá para estimar; ``unpriced_items`` diz quantos itens
    # ficaram de fora dela.
    estimate_cents: int
    unpriced_items: int
    # A soma do que os fornecedores já informaram; nulo se ninguém respondeu.
    quoted_cents: int | None
    currency: str
    snapshot: PartySnapshotResponse | None
    history: list[HistoryEntryResponse]
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_party(cls, party: Party) -> Self:
        """Exige ``party.items``, ``party.snapshot`` e ``party.events`` carregados."""
        # As contas (estimativa, total orçado) são as do domínio, e não uma
        # segunda versão delas aqui.
        state = to_state(party)
        estimates = {item.id: item.estimate_cents(state.guest_count) for item in state.items}
        items = [
            PartyItemResponse(
                id=item.id,
                listing_id=item.listing_id,
                offer_id=item.offer_id,
                vendor_id=item.vendor_id,
                parent_item_id=item.parent_item_id,
                relation=item.relation,
                category=item.category,
                name=item.name,
                pricing_model=item.pricing_model,
                unit_price_cents=public_price(item.pricing_model, item.unit_price_cents),
                minimum_cents=item.minimum_cents,
                currency=item.currency,
                quantity=item.quantity,
                configuration=dict(item.configuration),
                capacity=item.capacity,
                image_url=item.image_url,
                estimate_cents=estimates[item.id],
                quote=QuoteResponse.from_item(item),
            )
            for item in party.items
        ]
        return cls(
            id=party.id,
            owner_id=party.owner_id,
            title=party.title,
            event_type=party.event_type,
            event_at=party.event_at,
            guest_count=party.guest_count,
            status=party.status,
            quote_round=party.quote_round,
            version=party.version,
            items=items,
            estimate_cents=state.estimate_cents,
            unpriced_items=state.unpriced_items,
            quoted_cents=state.quoted_cents,
            currency=items[0].currency if items else "BRL",
            snapshot=(
                PartySnapshotResponse.from_snapshot(party.snapshot) if party.snapshot else None
            ),
            history=[HistoryEntryResponse.from_event(event) for event in party.events],
            created_at=party.created_at,
            updated_at=party.updated_at,
        )


class PartyListResponse(BaseModel):
    items: list[PartyResponse]
