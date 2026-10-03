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
from app.modules.catalog.pricing import PricingModel
from app.modules.parties.domain import (
    HistoryActor,
    HistoryKind,
    ItemRelation,
    PartyStatus,
    QuoteStatus,
)


class Party(Base):
    __tablename__ = "parties"
    __table_args__ = (
        CheckConstraint("guest_count IS NULL OR guest_count >= 1", name="guest_count_positive"),
        CheckConstraint("quote_round >= 0", name="quote_round_non_negative"),
        # Lista "minhas festas": do dono, da mais recente para a mais antiga.
        Index("ix_parties_owner_id_updated_at", "owner_id", "updated_at"),
    )

    # O id é gerado pelo app: a festa pode nascer antes de chegar ao servidor.
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(80))
    event_type: Mapped[str | None] = mapped_column(
        ForeignKey("event_types.slug", ondelete="RESTRICT")
    )
    event_at: Mapped[datetime | None] = mapped_column(UTCDateTime)
    guest_count: Mapped[int | None]
    status: Mapped[PartyStatus] = mapped_column(str_enum(PartyStatus, name="party_status"))
    # Quantas vezes o orçamento foi solicitado.
    quote_round: Mapped[int] = mapped_column(default=0)
    version: Mapped[int] = mapped_column()
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)

    # Controle otimista de concorrência: todo UPDATE confere a versão lida, e
    # dois dispositivos editando a mesma festa não se sobrescrevem em silêncio.
    # A resposta de um fornecedor também avança a versão: o app do cliente
    # descobre que a cópia dele ficou para trás.
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
    events: Mapped[list["PartyEvent"]] = relationship(
        back_populates="party",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="PartyEvent.sequence",
        lazy="raise",
    )


class PartyItem(Base):
    __tablename__ = "party_items"
    __table_args__ = (
        CheckConstraint("quantity >= 1", name="quantity_positive"),
        CheckConstraint("unit_price_cents >= 0", name="unit_price_non_negative"),
        # Sob consulta não tem preço: o zero é só o que a coluna exige.
        CheckConstraint(
            "pricing_model <> 'on_request' OR unit_price_cents = 0",
            name="on_request_has_no_price",
        ),
        CheckConstraint("minimum_cents IS NULL OR minimum_cents >= 0", name="minimum_non_negative"),
        CheckConstraint("quoted_cents IS NULL OR quoted_cents >= 0", name="quoted_non_negative"),
        # Um item vem de um anúncio ou de um serviço próprio, nunca dos dois.
        CheckConstraint("listing_id IS NULL OR offer_id IS NULL", name="single_source"),
        UniqueConstraint("party_id", "listing_id"),
        UniqueConstraint("party_id", "offer_id"),
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
    # O serviço próprio de um anúncio, quando o item é um deles.
    offer_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("listing_offers.id", ondelete="SET NULL"), index=True
    )
    # De quem é o item: é para ele que o pedido de orçamento vai. Copiado na
    # entrada, para o pedido não depender de o anúncio continuar existindo.
    vendor_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("vendor_profiles.id", ondelete="SET NULL"), index=True
    )
    # O item da mesma festa a que este está ligado (veja ``relation``).
    parent_item_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("party_items.id", ondelete="SET NULL"), index=True
    )
    relation: Mapped[ItemRelation] = mapped_column(
        str_enum(ItemRelation, name="item_relation"), default=ItemRelation.INDEPENDENT
    )
    # Cópia dos dados do anúncio no momento em que o item entrou na festa: uma
    # mudança posterior de preço não altera o que o cliente já planejou.
    category: Mapped[str] = mapped_column(String(40))
    name: Mapped[str] = mapped_column(String(120))
    pricing_model: Mapped[PricingModel] = mapped_column(
        str_enum(PricingModel, name="pricing_model")
    )
    unit_price_cents: Mapped[int]
    minimum_cents: Mapped[int | None]
    currency: Mapped[str] = mapped_column(String(3))
    image_url: Mapped[str | None] = mapped_column(String(500))
    # Quantas pessoas o espaço comporta, quando o anúncio informa.
    capacity: Mapped[int | None]
    quantity: Mapped[int]
    # O que a pessoa informou ao configurar o item (duração, tema, observações).
    configuration: Mapped[dict[str, Any]] = mapped_column(JSON, default=dict)
    position: Mapped[int] = mapped_column(default=0)
    # A resposta do fornecedor a este item.
    quote_status: Mapped[QuoteStatus] = mapped_column(
        str_enum(QuoteStatus, name="quote_status"), default=QuoteStatus.NONE
    )
    quoted_cents: Mapped[int | None] = mapped_column(BigInteger)
    quote_message: Mapped[str | None] = mapped_column(String(500))
    quote_responded_at: Mapped[datetime | None] = mapped_column(UTCDateTime)

    party: Mapped[Party] = relationship(back_populates="items", lazy="raise")


class PartySnapshot(Base):
    """Retrato da estimativa no momento em que o orçamento foi solicitado."""

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


class PartyEvent(Base):
    """Um acontecimento da festa. Só se acrescenta: nada aqui é alterado."""

    __tablename__ = "party_events"
    # A constraint também é o índice do histórico de uma festa, já em ordem.
    __table_args__ = (UniqueConstraint("party_id", "sequence"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    party_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("parties.id", ondelete="CASCADE"))
    # Posição no histórico da festa: 1, 2, 3...
    sequence: Mapped[int]
    kind: Mapped[HistoryKind] = mapped_column(str_enum(HistoryKind, name="history_kind"))
    actor: Mapped[HistoryActor] = mapped_column(str_enum(HistoryActor, name="history_actor"))
    # Em que rodada de orçamento aconteceu.
    quote_round: Mapped[int]
    # O item a que se refere, quando é a resposta de um fornecedor. Sem chave
    # estrangeira e com o nome copiado: o registro sobrevive ao item.
    item_id: Mapped[uuid.UUID | None] = mapped_column(Uuid)
    item_name: Mapped[str | None] = mapped_column(String(120))
    message: Mapped[str | None] = mapped_column(String(500))
    amount_cents: Mapped[int | None] = mapped_column(BigInteger)
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)

    party: Mapped[Party] = relationship(back_populates="events", lazy="raise")
