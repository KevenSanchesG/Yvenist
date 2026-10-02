import uuid
from datetime import datetime
from decimal import Decimal
from enum import StrEnum

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Column,
    ForeignKey,
    Index,
    Numeric,
    String,
    Table,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, UTCDateTime, str_enum, utcnow


class ListingStatus(StrEnum):
    DRAFT = "draft"
    PENDING_REVIEW = "pending_review"
    PUBLISHED = "published"
    REJECTED = "rejected"
    ARCHIVED = "archived"


class CancellationPolicy(StrEnum):
    FLEXIBLE = "flexible"
    MODERATE = "moderate"


class Category(Base):
    """O que é oferecido: salão, atração, buffet... Um anúncio tem uma categoria."""

    __tablename__ = "categories"

    slug: Mapped[str] = mapped_column(String(40), primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    # Chave que o app traduz para um ícone.
    icon: Mapped[str] = mapped_column(String(40))
    sort_order: Mapped[int] = mapped_column(default=0)
    is_active: Mapped[bool] = mapped_column(default=True)


class EventType(Base):
    """A ocasião: casamento, 15 anos... Um anúncio pode atender várias."""

    __tablename__ = "event_types"

    slug: Mapped[str] = mapped_column(String(40), primary_key=True)
    name: Mapped[str] = mapped_column(String(60))
    sort_order: Mapped[int] = mapped_column(default=0)
    is_active: Mapped[bool] = mapped_column(default=True)


listing_event_types = Table(
    "listing_event_types",
    Base.metadata,
    Column("listing_id", ForeignKey("listings.id", ondelete="CASCADE"), primary_key=True),
    Column(
        "event_type_slug",
        ForeignKey("event_types.slug", ondelete="RESTRICT"),
        primary_key=True,
    ),
    # A chave primária começa por listing_id; o filtro por tipo de evento
    # precisa de um índice próprio.
    Index("ix_listing_event_types_event_type_slug", "event_type_slug"),
)


class Listing(Base):
    __tablename__ = "listings"
    __table_args__ = (
        CheckConstraint("price_from_cents >= 0", name="price_non_negative"),
        CheckConstraint("capacity IS NULL OR capacity > 0", name="capacity_positive"),
        CheckConstraint("area_m2 IS NULL OR area_m2 > 0", name="area_positive"),
        CheckConstraint("rating_count >= 0", name="rating_count_non_negative"),
        CheckConstraint(
            "status <> 'published' OR published_at IS NOT NULL",
            name="published_has_date",
        ),
        # A vitrine sempre filtra por status e ordena por um destes critérios
        # com o id como desempate; os índices cobrem a paginação por cursor.
        Index("ix_listings_status_rating_count", "status", "rating_count", "id"),
        Index("ix_listings_status_price", "status", "price_from_cents", "id"),
        Index("ix_listings_status_published_at", "status", "published_at", "id"),
        Index("ix_listings_status_category", "status", "category_slug"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("vendor_profiles.id", ondelete="CASCADE"), index=True
    )
    category_slug: Mapped[str] = mapped_column(ForeignKey("categories.slug", ondelete="RESTRICT"))
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text)
    neighborhood: Mapped[str | None] = mapped_column(String(80))
    city: Mapped[str] = mapped_column(String(80))
    state: Mapped[str] = mapped_column(String(2))
    # Dinheiro sempre em centavos inteiros: nada de ponto flutuante.
    price_from_cents: Mapped[int]
    currency: Mapped[str] = mapped_column(String(3), default="BRL")
    capacity: Mapped[int | None]
    area_m2: Mapped[int | None]
    amenities: Mapped[list[str]] = mapped_column(JSON, default=list)
    cancellation_policy: Mapped[CancellationPolicy] = mapped_column(
        str_enum(CancellationPolicy, name="cancellation_policy"),
        default=CancellationPolicy.FLEXIBLE,
    )
    cover_image_url: Mapped[str | None] = mapped_column(String(500))
    status: Mapped[ListingStatus] = mapped_column(
        str_enum(ListingStatus, name="listing_status"), default=ListingStatus.PENDING_REVIEW
    )
    rejection_reason: Mapped[str | None] = mapped_column(String(500))
    # Agregados das avaliações, mantidos aqui para a vitrine não precisar
    # recalcular a cada listagem. Serão alimentados pelo módulo de avaliações.
    rating_average: Mapped[Decimal] = mapped_column(Numeric(3, 2), default=Decimal("0"))
    rating_count: Mapped[int] = mapped_column(default=0)
    # Texto de busca já normalizado (minúsculas, sem acentos).
    search_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow, onupdate=utcnow)
    published_at: Mapped[datetime | None] = mapped_column(UTCDateTime)

    # lazy="raise": carregar tipos de evento exige pedir explicitamente, o que
    # impede um N+1 acidental nas listagens.
    event_types: Mapped[list[EventType]] = relationship(
        secondary=listing_event_types,
        lazy="raise",
        order_by=EventType.sort_order,
    )
