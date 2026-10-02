import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base, UTCDateTime, str_enum, utcnow
from app.modules.parties.domain import PartyStatus


class Party(Base):
    __tablename__ = "parties"
    __table_args__ = (
        CheckConstraint("guest_count IS NULL OR guest_count >= 1", name="guest_count_positive"),
        # Lista "minhas festas": do dono, da mais recente para a mais antiga.
        Index("ix_parties_owner_id_updated_at", "owner_id", "updated_at"),
    )

    # O id é gerado pelo app: a festa pode nascer antes de chegar ao servidor.
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(80))
    event_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    guest_count: Mapped[int | None]
    status: Mapped[PartyStatus] = mapped_column(str_enum(PartyStatus, name="party_status"))
    version: Mapped[int] = mapped_column()
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)

    # Controle otimista de concorrência: todo UPDATE confere a versão lida, e
    # dois dispositivos editando a mesma festa não se sobrescrevem em silêncio.
    __mapper_args__ = {"version_id_col": version}  # noqa: RUF012

    items: Mapped[list["PartyItem"]] = relationship(
        back_populates="party",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="PartyItem.position",
        lazy="raise",
    )
    snapshot: Mapped["PartySnapshot | None"] = relationship(
        back_populates="party",
        cascade="all, delete-orphan",
        passive_deletes=True,
        lazy="raise",
    )


class PartyItem(Base):
    __tablename__ = "party_items"
    __table_args__ = (
        CheckConstraint("quantity >= 1", name="quantity_positive"),
        CheckConstraint("unit_price_cents >= 0", name="unit_price_non_negative"),
        UniqueConstraint("party_id", "listing_id"),
        # Regra "um salão por festa" garantida também pelo banco.
        Index(
            "uq_party_items_one_venue_per_party",
            "party_id",
            unique=True,
            sqlite_where=text("category = 'venue'"),
            postgresql_where=text("category = 'venue'"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    # Sem índice próprio: a constraint única (party_id, listing_id) já começa
    # por party_id e atende às buscas pelos itens de uma festa.
    party_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("parties.id", ondelete="CASCADE"))
    # Se o anúncio for apagado, o item continua na festa com os dados copiados.
    listing_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("listings.id", ondelete="SET NULL"), index=True
    )
    # Cópia dos dados do anúncio no momento em que o item entrou na festa: uma
    # mudança posterior de preço não altera o que o cliente já planejou.
    category: Mapped[str] = mapped_column(String(40))
    name: Mapped[str] = mapped_column(String(120))
    unit_price_cents: Mapped[int]
    currency: Mapped[str] = mapped_column(String(3))
    image_url: Mapped[str | None] = mapped_column(String(500))
    quantity: Mapped[int]
    position: Mapped[int] = mapped_column(default=0)

    party: Mapped[Party] = relationship(back_populates="items", lazy="raise")


class PartySnapshot(Base):
    """Retrato do orçamento no momento em que a festa foi travada."""

    __tablename__ = "party_snapshots"

    party_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("parties.id", ondelete="CASCADE"), primary_key=True
    )
    generated_at: Mapped[datetime] = mapped_column(UTCDateTime)
    expires_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    total_cents: Mapped[int] = mapped_column(BigInteger)
    currency: Mapped[str] = mapped_column(String(3))
    breakdown: Mapped[list[dict[str, Any]]] = mapped_column(JSON)

    party: Mapped[Party] = relationship(back_populates="snapshot", lazy="raise")
