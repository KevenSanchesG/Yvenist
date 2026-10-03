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
from app.modules.catalog.pricing import PricingModel


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

# Parceiros que um anúncio recomenda: outros anúncios, de qualquer fornecedor.
# É uma indicação, e não um vínculo: o parceiro é contratado à parte.
listing_partners = Table(
    "listing_partners",
    Base.metadata,
    Column("listing_id", ForeignKey("listings.id", ondelete="CASCADE"), primary_key=True),
    Column("partner_listing_id", ForeignKey("listings.id", ondelete="CASCADE"), primary_key=True),
    CheckConstraint("listing_id <> partner_listing_id", name="not_self"),
    # A chave primária começa por listing_id; apagar um anúncio procura também
    # as linhas em que ele é o parceiro.
    Index("ix_listing_partners_partner_listing_id", "partner_listing_id"),
)


class Listing(Base):
    __tablename__ = "listings"
    __table_args__ = (
        CheckConstraint("price_from_cents >= 0", name="price_non_negative"),
        # Sob consulta não tem preço: o zero só existe para a coluna ordenar.
        CheckConstraint(
            "pricing_model <> 'on_request' OR price_from_cents = 0",
            name="on_request_has_no_price",
        ),
        CheckConstraint(
            "minimum_price_cents IS NULL OR minimum_price_cents >= 0",
            name="minimum_price_non_negative",
        ),
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
    # A que o preço se refere (o serviço inteiro, cada pessoa, cada hora...).
    pricing_model: Mapped[PricingModel] = mapped_column(
        str_enum(PricingModel, name="pricing_model"), default=PricingModel.FIXED
    )
    # Valor mínimo cobrado, qualquer que seja a conta do modelo.
    minimum_price_cents: Mapped[int | None]
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
    offers: Mapped[list["ListingOffer"]] = relationship(
        back_populates="listing",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="ListingOffer.position",
        lazy="raise",
    )
    partners: Mapped[list["Listing"]] = relationship(
        secondary=listing_partners,
        primaryjoin=lambda: Listing.id == listing_partners.c.listing_id,
        secondaryjoin=lambda: Listing.id == listing_partners.c.partner_listing_id,
        lazy="raise",
    )


class ListingOffer(Base):
    """Serviço que o próprio anunciante oferece junto com o anúncio.

    O buffet do salão, a atração da casa, uma taxa de limpeza. Não é um anúncio:
    não aparece na busca, não passa por análise sozinho e só pode ser contratado
    com o anúncio a que pertence.
    """

    __tablename__ = "listing_offers"
    __table_args__ = (
        CheckConstraint("price_cents >= 0", name="price_non_negative"),
        CheckConstraint(
            "pricing_model <> 'on_request' OR price_cents = 0",
            name="on_request_has_no_price",
        ),
        CheckConstraint(
            "minimum_price_cents IS NULL OR minimum_price_cents >= 0",
            name="minimum_price_non_negative",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    listing_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("listings.id", ondelete="CASCADE"), index=True
    )
    category_slug: Mapped[str] = mapped_column(ForeignKey("categories.slug", ondelete="RESTRICT"))
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(String(300))
    pricing_model: Mapped[PricingModel] = mapped_column(
        str_enum(PricingModel, name="pricing_model")
    )
    price_cents: Mapped[int]
    minimum_price_cents: Mapped[int | None]
    # Obrigatório: quem contrata o anúncio contrata este serviço junto.
    is_required: Mapped[bool] = mapped_column(default=False)
    position: Mapped[int] = mapped_column(default=0)

    listing: Mapped[Listing] = relationship(back_populates="offers", lazy="raise")
