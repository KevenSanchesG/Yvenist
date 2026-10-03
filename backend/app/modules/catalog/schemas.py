import uuid
from typing import Self

from pydantic import BaseModel, ConfigDict

from app.modules.catalog.models import CancellationPolicy, Listing, ListingOffer, ListingStatus
from app.modules.catalog.pricing import PricingModel, public_price


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
    pricing_model: PricingModel
    # Nulo quando o anúncio é sob consulta.
    price_from_cents: int | None
    minimum_price_cents: int | None
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
            pricing_model=listing.pricing_model,
            price_from_cents=public_price(listing.pricing_model, listing.price_from_cents),
            minimum_price_cents=listing.minimum_price_cents,
            currency=listing.currency,
            cover_image_url=listing.cover_image_url,
            rating_average=float(listing.rating_average),
            rating_count=listing.rating_count,
        )


class OfferResponse(BaseModel):
    """Um serviço que o próprio anunciante oferece junto com o anúncio."""

    id: uuid.UUID
    category: str
    name: str
    description: str | None
    pricing_model: PricingModel
    price_cents: int | None
    minimum_price_cents: int | None
    required: bool

    @classmethod
    def from_offer(cls, offer: ListingOffer) -> Self:
        return cls(
            id=offer.id,
            category=offer.category_slug,
            name=offer.name,
            description=offer.description,
            pricing_model=offer.pricing_model,
            price_cents=public_price(offer.pricing_model, offer.price_cents),
            minimum_price_cents=offer.minimum_price_cents,
            required=offer.is_required,
        )


class ListingDetail(ListingSummary):
    description: str
    capacity: int | None
    area_m2: int | None
    amenities: list[str]
    cancellation_policy: CancellationPolicy
    event_types: list[str]
    offers: list[OfferResponse]
    # Só os parceiros que estão publicados: um anúncio recolhido não é indicado.
    partners: list[ListingSummary]

    @classmethod
    def from_listing(cls, listing: Listing) -> Self:
        """Exige ``event_types``, ``offers`` e ``partners`` já carregados."""
        summary = ListingSummary.from_listing(listing)
        partners = sorted(
            (p for p in listing.partners if p.status is ListingStatus.PUBLISHED),
            key=lambda partner: (partner.title, partner.id),
        )
        return cls(
            **summary.model_dump(),
            description=listing.description,
            capacity=listing.capacity,
            area_m2=listing.area_m2,
            amenities=list(listing.amenities),
            cancellation_policy=listing.cancellation_policy,
            event_types=[event_type.slug for event_type in listing.event_types],
            offers=[OfferResponse.from_offer(offer) for offer in listing.offers],
            partners=[ListingSummary.from_listing(partner) for partner in partners],
        )


class ListingPage(BaseModel):
    items: list[ListingSummary]
    # Passe este valor em ``cursor`` para buscar a página seguinte; null no fim.
    next_cursor: str | None
