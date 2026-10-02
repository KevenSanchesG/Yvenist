import uuid
from datetime import UTC, datetime
from typing import Annotated, Self

from pydantic import AfterValidator, AwareDatetime, BaseModel, Field

from app.modules.parties.domain import (
    MAX_ITEM_QUANTITY,
    MAX_ITEMS_PER_PARTY,
    DesiredItem,
    DesiredParty,
    PartyStatus,
)
from app.modules.parties.models import Party, PartySnapshot


def _clean_title(value: str) -> str:
    cleaned = " ".join(value.split())
    if not cleaned:
        raise ValueError("O nome da festa não pode ficar vazio.")
    return cleaned


class PartyItemInput(BaseModel):
    id: uuid.UUID
    # Obrigatório para item novo; ignorado para item que já está na festa.
    listing_id: uuid.UUID | None = None
    quantity: int = Field(ge=1, le=MAX_ITEM_QUANTITY)


class PartyInput(BaseModel):
    """Estado que o cliente quer gravar para a festa."""

    title: Annotated[str, Field(max_length=80), AfterValidator(_clean_title)]
    event_at: AwareDatetime | None = None
    guest_count: int | None = Field(default=None, ge=1, le=100_000)
    status: PartyStatus
    items: list[PartyItemInput] = Field(default_factory=list, max_length=MAX_ITEMS_PER_PARTY)
    # Versão que o cliente conhece (0 ou ausente ao criar). Se outra alteração
    # tiver sido gravada nesse meio tempo, a resposta é 409.
    version: int | None = Field(default=None, ge=0)

    def to_desired(self) -> DesiredParty:
        return DesiredParty(
            title=self.title,
            # Sempre em UTC: é assim que o banco guarda e que a API responde.
            event_at=self.event_at.astimezone(UTC) if self.event_at else None,
            guest_count=self.guest_count,
            status=self.status,
            items=tuple(
                DesiredItem(id=item.id, listing_id=item.listing_id, quantity=item.quantity)
                for item in self.items
            ),
        )


class PartyItemResponse(BaseModel):
    id: uuid.UUID
    listing_id: uuid.UUID | None
    category: str
    name: str
    unit_price_cents: int
    currency: str
    quantity: int
    image_url: str | None


class SnapshotLine(BaseModel):
    listing_id: uuid.UUID | None
    category: str
    name: str
    unit_price_cents: int
    quantity: int
    subtotal_cents: int


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


class PartyResponse(BaseModel):
    id: uuid.UUID
    title: str
    event_at: datetime | None
    guest_count: int | None
    status: PartyStatus
    version: int
    items: list[PartyItemResponse]
    total_cents: int
    currency: str
    snapshot: PartySnapshotResponse | None
    created_at: datetime
    updated_at: datetime

    @classmethod
    def from_party(cls, party: Party) -> Self:
        """Exige ``party.items`` e ``party.snapshot`` já carregados."""
        items = [
            PartyItemResponse(
                id=item.id,
                listing_id=item.listing_id,
                category=item.category,
                name=item.name,
                unit_price_cents=item.unit_price_cents,
                currency=item.currency,
                quantity=item.quantity,
                image_url=item.image_url,
            )
            for item in party.items
        ]
        return cls(
            id=party.id,
            title=party.title,
            event_at=party.event_at,
            guest_count=party.guest_count,
            status=party.status,
            version=party.version,
            items=items,
            total_cents=sum(item.unit_price_cents * item.quantity for item in items),
            currency=items[0].currency if items else "BRL",
            snapshot=(
                PartySnapshotResponse.from_snapshot(party.snapshot) if party.snapshot else None
            ),
            created_at=party.created_at,
            updated_at=party.updated_at,
        )


class PartyListResponse(BaseModel):
    items: list[PartyResponse]
