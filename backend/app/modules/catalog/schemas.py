import uuid
from typing import Self

from pydantic import BaseModel, ConfigDict

from app.modules.catalog.models import CancellationPolicy, Listing


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    name: str
    icon: str


class EventTypeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    slug: str
    name: str


class ListingSummary(BaseModel):
    """O que um card da vitrine precisa. Sem relações: uma consulta só."""

    id: uuid.UUID
    title: str
    category: str
    neighborhood: str | None
    city: str
    state: str
    price_from_cents: int
    currency: str
    cover_image_url: str | None
    rating_average: float
    rating_count: int

    @classmethod
    def from_listing(cls, listing: Listing) -> Self:
        return cls(
            id=listing.id,
            title=listing.title,
            category=listing.category_slug,
            neighborhood=listing.neighborhood,
            city=listing.city,
            state=listing.state,
            price_from_cents=listing.price_from_cents,
            currency=listing.currency,
            cover_image_url=listing.cover_image_url,
            rating_average=float(listing.rating_average),
            rating_count=listing.rating_count,
        )


class ListingDetail(ListingSummary):
    description: str
    capacity: int | None
    area_m2: int | None
    amenities: list[str]
    cancellation_policy: CancellationPolicy
    event_types: list[str]

    @classmethod
    def from_listing(cls, listing: Listing) -> Self:
        """Exige ``listing.event_types`` já carregado."""
        summary = ListingSummary.from_listing(listing)
        return cls(
            **summary.model_dump(),
            description=listing.description,
            capacity=listing.capacity,
            area_m2=listing.area_m2,
            amenities=list(listing.amenities),
            cancellation_policy=listing.cancellation_policy,
            event_types=[event_type.slug for event_type in listing.event_types],
        )


class ListingPage(BaseModel):
    items: list[ListingSummary]
    # Passe este valor em ``cursor`` para buscar a página seguinte; null no fim.
    next_cursor: str | None
