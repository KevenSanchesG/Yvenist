"""party composition and quotes

A festa passa a ser a composição de um evento: ganha o tipo de evento e a
rodada de orçamento; cada item ganha a configuração, a forma de cobrança, a
ligação com outro item, o fornecedor a quem o pedido vai e a resposta dele; e
tudo o que acontece fica em ``party_events``.

Nenhum dado é apagado. O que já existe é levado para o formato novo:

- um item antigo somava preço vezes quantidade: é o que "por unidade" quer
  dizer, então o total de cada festa continua o mesmo;
- o fornecedor de cada item é o dono do anúncio dele;
- uma festa com o orçamento solicitado está na primeira rodada, com todos os
  itens esperando resposta.

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ENUM = sa.String(length=32)
TIMESTAMP = sa.DateTime(timezone=True)

OLD_PARTY_STATUSES = "status IN ('draft', 'planning', 'locked', 'paid', 'cancelled')"
PARTY_STATUSES = (
    "status IN ('draft', 'planning', 'locked', 'quoted', 'edit_requested', 'confirmed', "
    "'paid', 'cancelled')"
)
PRICING_MODELS = "pricing_model IN ('fixed', 'per_person', 'per_hour', 'per_unit', 'on_request')"
RELATIONS = "relation IN ('independent', 'linked', 'required', 'recommended')"
QUOTE_STATUSES = "quote_status IN ('none', 'pending', 'quoted', 'changes_requested', 'declined')"
HISTORY_KINDS = (
    "kind IN ('quote_requested', 'reopened', 'vendor_quoted', 'vendor_requested_changes', "
    "'vendor_declined', 'confirmed', 'cancelled')"
)
HISTORY_ACTORS = "actor IN ('client', 'vendor')"


def upgrade() -> None:
    # ---------------- parties ----------------
    # As colunas obrigatórias entram aceitando nulo, recebem o valor das linhas
    # que já existem e só então ficam obrigatórias.
    op.add_column("parties", sa.Column("event_type", sa.String(length=40), nullable=True))
    op.add_column("parties", sa.Column("quote_round", sa.Integer(), nullable=True))
    op.execute("UPDATE parties SET quote_round = CASE WHEN status = 'locked' THEN 1 ELSE 0 END")
    with op.batch_alter_table("parties") as batch:
        batch.alter_column("quote_round", existing_type=sa.Integer(), nullable=False)
        batch.create_foreign_key(
            op.f("fk_parties_event_type_event_types"),
            "event_types",
            ["event_type"],
            ["slug"],
            ondelete="RESTRICT",
        )
        batch.create_check_constraint(
            op.f("ck_parties_quote_round_non_negative"), "quote_round >= 0"
        )
        batch.drop_constraint(op.f("ck_parties_party_status"), type_="check")
        batch.create_check_constraint(op.f("ck_parties_party_status"), PARTY_STATUSES)

    # ---------------- party_items ----------------
    op.add_column("party_items", sa.Column("offer_id", sa.Uuid(), nullable=True))
    op.add_column("party_items", sa.Column("vendor_id", sa.Uuid(), nullable=True))
    op.add_column("party_items", sa.Column("parent_item_id", sa.Uuid(), nullable=True))
    op.add_column("party_items", sa.Column("relation", ENUM, nullable=True))
    op.add_column("party_items", sa.Column("pricing_model", ENUM, nullable=True))
    op.add_column("party_items", sa.Column("minimum_cents", sa.Integer(), nullable=True))
    op.add_column("party_items", sa.Column("capacity", sa.Integer(), nullable=True))
    op.add_column("party_items", sa.Column("configuration", sa.JSON(), nullable=True))
    op.add_column("party_items", sa.Column("quote_status", ENUM, nullable=True))
    op.add_column("party_items", sa.Column("quoted_cents", sa.BigInteger(), nullable=True))
    op.add_column("party_items", sa.Column("quote_message", sa.String(length=500), nullable=True))
    op.add_column("party_items", sa.Column("quote_responded_at", TIMESTAMP, nullable=True))
    op.execute(
        "UPDATE party_items SET relation = 'independent', pricing_model = 'per_unit', "
        "configuration = '{}', "
        "vendor_id = (SELECT vendor_id FROM listings WHERE listings.id = party_items.listing_id), "
        "quote_status = CASE WHEN party_id IN (SELECT id FROM parties WHERE status = 'locked') "
        "THEN 'pending' ELSE 'none' END"
    )
    # No SQLite o bloco abaixo recria a tabela e, com ela, os índices. Um índice
    # parcial recriado sem a condição viraria "um item por festa" e barraria as
    # festas que já existem: o de "um salão por festa" sai antes e volta depois,
    # escrito por extenso.
    op.drop_index("uq_party_items_one_venue_per_party", table_name="party_items")
    with op.batch_alter_table("party_items") as batch:
        batch.alter_column("relation", existing_type=ENUM, nullable=False)
        batch.alter_column("pricing_model", existing_type=ENUM, nullable=False)
        batch.alter_column("configuration", existing_type=sa.JSON(), nullable=False)
        batch.alter_column("quote_status", existing_type=ENUM, nullable=False)
        batch.create_foreign_key(
            op.f("fk_party_items_offer_id_listing_offers"),
            "listing_offers",
            ["offer_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            op.f("fk_party_items_vendor_id_vendor_profiles"),
            "vendor_profiles",
            ["vendor_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            op.f("fk_party_items_parent_item_id_party_items"),
            "party_items",
            ["parent_item_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_unique_constraint(
            op.f("uq_party_items_party_id_offer_id"), ["party_id", "offer_id"]
        )
        batch.create_check_constraint(op.f("ck_party_items_item_relation"), RELATIONS)
        batch.create_check_constraint(op.f("ck_party_items_pricing_model"), PRICING_MODELS)
        batch.create_check_constraint(op.f("ck_party_items_quote_status"), QUOTE_STATUSES)
        batch.create_check_constraint(
            op.f("ck_party_items_on_request_has_no_price"),
            "pricing_model <> 'on_request' OR unit_price_cents = 0",
        )
        batch.create_check_constraint(
            op.f("ck_party_items_minimum_non_negative"),
            "minimum_cents IS NULL OR minimum_cents >= 0",
        )
        batch.create_check_constraint(
            op.f("ck_party_items_quoted_non_negative"),
            "quoted_cents IS NULL OR quoted_cents >= 0",
        )
        batch.create_check_constraint(
            op.f("ck_party_items_single_source"), "listing_id IS NULL OR offer_id IS NULL"
        )
    op.create_index(op.f("ix_party_items_offer_id"), "party_items", ["offer_id"])
    op.create_index(op.f("ix_party_items_vendor_id"), "party_items", ["vendor_id"])
    op.create_index(op.f("ix_party_items_parent_item_id"), "party_items", ["parent_item_id"])
    op.create_index(
        "uq_party_items_one_venue_per_party",
        "party_items",
        ["party_id"],
        unique=True,
        sqlite_where=sa.text("category = 'venue'"),
        postgresql_where=sa.text("category = 'venue'"),
    )

    # ---------------- party_events ----------------
    op.create_table(
        "party_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("party_id", sa.Uuid(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("kind", ENUM, nullable=False),
        sa.Column("actor", ENUM, nullable=False),
        sa.Column("quote_round", sa.Integer(), nullable=False),
        sa.Column("item_id", sa.Uuid(), nullable=True),
        sa.Column("item_name", sa.String(length=120), nullable=True),
        sa.Column("message", sa.String(length=500), nullable=True),
        sa.Column("amount_cents", sa.BigInteger(), nullable=True),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.CheckConstraint(HISTORY_KINDS, name=op.f("ck_party_events_history_kind")),
        sa.CheckConstraint(HISTORY_ACTORS, name=op.f("ck_party_events_history_actor")),
        sa.ForeignKeyConstraint(
            ["party_id"],
            ["parties.id"],
            name=op.f("fk_party_events_party_id_parties"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_party_events")),
        sa.UniqueConstraint("party_id", "sequence", name=op.f("uq_party_events_party_id_sequence")),
    )


def downgrade() -> None:
    # Apaga o histórico, as respostas dos fornecedores e a configuração dos
    # itens. Festas em um status que a versão anterior não conhece voltam para
    # o planejamento, e um serviço próprio fica como um item sem anúncio. Só
    # faz sentido em um banco sem dados a preservar.
    op.drop_table("party_events")

    op.drop_index(op.f("ix_party_items_parent_item_id"), table_name="party_items")
    op.drop_index(op.f("ix_party_items_vendor_id"), table_name="party_items")
    op.drop_index(op.f("ix_party_items_offer_id"), table_name="party_items")
    op.drop_index("uq_party_items_one_venue_per_party", table_name="party_items")
    with op.batch_alter_table("party_items") as batch:
        batch.drop_constraint(op.f("ck_party_items_single_source"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_quoted_non_negative"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_minimum_non_negative"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_on_request_has_no_price"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_quote_status"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_pricing_model"), type_="check")
        batch.drop_constraint(op.f("ck_party_items_item_relation"), type_="check")
        batch.drop_constraint(op.f("uq_party_items_party_id_offer_id"), type_="unique")
        batch.drop_constraint(op.f("fk_party_items_parent_item_id_party_items"), type_="foreignkey")
        batch.drop_constraint(op.f("fk_party_items_vendor_id_vendor_profiles"), type_="foreignkey")
        batch.drop_constraint(op.f("fk_party_items_offer_id_listing_offers"), type_="foreignkey")
        for column in (
            "quote_responded_at",
            "quote_message",
            "quoted_cents",
            "quote_status",
            "configuration",
            "capacity",
            "minimum_cents",
            "pricing_model",
            "relation",
            "parent_item_id",
            "vendor_id",
            "offer_id",
        ):
            batch.drop_column(column)
    op.create_index(
        "uq_party_items_one_venue_per_party",
        "party_items",
        ["party_id"],
        unique=True,
        sqlite_where=sa.text("category = 'venue'"),
        postgresql_where=sa.text("category = 'venue'"),
    )

    op.execute(
        "UPDATE parties SET status = 'planning' "
        "WHERE status IN ('quoted', 'edit_requested', 'confirmed')"
    )
    with op.batch_alter_table("parties") as batch:
        batch.drop_constraint(op.f("ck_parties_party_status"), type_="check")
        batch.create_check_constraint(op.f("ck_parties_party_status"), OLD_PARTY_STATUSES)
        batch.drop_constraint(op.f("ck_parties_quote_round_non_negative"), type_="check")
        batch.drop_constraint(op.f("fk_parties_event_type_event_types"), type_="foreignkey")
        batch.drop_column("quote_round")
        batch.drop_column("event_type")
