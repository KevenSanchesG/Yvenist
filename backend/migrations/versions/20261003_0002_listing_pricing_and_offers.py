"""listing pricing, own services and partners

Cada anúncio passa a dizer como cobra (``pricing_model``) e, se houver, o valor
mínimo. Ganha também os serviços que o próprio anunciante oferece junto
(``listing_offers``) e os parceiros que recomenda (``listing_partners``).

Nenhum dado é apagado. Os anúncios que já existem informavam um preço inicial
pelo evento: passam a ser de valor fixo, que é o que esse preço já significava.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-03
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ENUM = sa.String(length=32)
PRICING_MODEL_CHECK = (
    "pricing_model IN ('fixed', 'per_person', 'per_hour', 'per_unit', 'on_request')"
)
ON_REQUEST_CHECK = "pricing_model <> 'on_request' OR {price} = 0"
MINIMUM_CHECK = "minimum_price_cents IS NULL OR minimum_price_cents >= 0"


def upgrade() -> None:
    # Em três passos, para a coluna nova nascer preenchida nos anúncios que já
    # existem: entra aceitando nulo, recebe o valor e só então fica obrigatória.
    op.add_column("listings", sa.Column("pricing_model", ENUM, nullable=True))
    op.add_column("listings", sa.Column("minimum_price_cents", sa.Integer(), nullable=True))
    op.execute("UPDATE listings SET pricing_model = 'fixed'")
    with op.batch_alter_table("listings") as batch:
        batch.alter_column("pricing_model", existing_type=ENUM, nullable=False)
        batch.create_check_constraint(op.f("ck_listings_pricing_model"), PRICING_MODEL_CHECK)
        batch.create_check_constraint(
            op.f("ck_listings_on_request_has_no_price"),
            ON_REQUEST_CHECK.format(price="price_from_cents"),
        )
        batch.create_check_constraint(op.f("ck_listings_minimum_price_non_negative"), MINIMUM_CHECK)

    op.create_table(
        "listing_offers",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("listing_id", sa.Uuid(), nullable=False),
        sa.Column("category_slug", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.String(length=300), nullable=True),
        sa.Column("pricing_model", ENUM, nullable=False),
        sa.Column("price_cents", sa.Integer(), nullable=False),
        sa.Column("minimum_price_cents", sa.Integer(), nullable=True),
        sa.Column("is_required", sa.Boolean(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.CheckConstraint(PRICING_MODEL_CHECK, name=op.f("ck_listing_offers_pricing_model")),
        sa.CheckConstraint("price_cents >= 0", name=op.f("ck_listing_offers_price_non_negative")),
        sa.CheckConstraint(
            ON_REQUEST_CHECK.format(price="price_cents"),
            name=op.f("ck_listing_offers_on_request_has_no_price"),
        ),
        sa.CheckConstraint(
            MINIMUM_CHECK, name=op.f("ck_listing_offers_minimum_price_non_negative")
        ),
        sa.ForeignKeyConstraint(
            ["listing_id"],
            ["listings.id"],
            name=op.f("fk_listing_offers_listing_id_listings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["category_slug"],
            ["categories.slug"],
            name=op.f("fk_listing_offers_category_slug_categories"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_listing_offers")),
    )
    op.create_index(op.f("ix_listing_offers_listing_id"), "listing_offers", ["listing_id"])

    op.create_table(
        "listing_partners",
        sa.Column("listing_id", sa.Uuid(), nullable=False),
        sa.Column("partner_listing_id", sa.Uuid(), nullable=False),
        sa.CheckConstraint(
            "listing_id <> partner_listing_id", name=op.f("ck_listing_partners_not_self")
        ),
        sa.ForeignKeyConstraint(
            ["listing_id"],
            ["listings.id"],
            name=op.f("fk_listing_partners_listing_id_listings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["partner_listing_id"],
            ["listings.id"],
            name=op.f("fk_listing_partners_partner_listing_id_listings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "listing_id", "partner_listing_id", name=op.f("pk_listing_partners")
        ),
    )
    op.create_index(
        "ix_listing_partners_partner_listing_id", "listing_partners", ["partner_listing_id"]
    )


def downgrade() -> None:
    # Apaga os serviços próprios, os parceiros e a forma de cobrança de cada
    # anúncio: só faz sentido em um banco sem dados a preservar.
    op.drop_table("listing_partners")
    op.drop_table("listing_offers")
    with op.batch_alter_table("listings") as batch:
        batch.drop_constraint(op.f("ck_listings_minimum_price_non_negative"), type_="check")
        batch.drop_constraint(op.f("ck_listings_on_request_has_no_price"), type_="check")
        batch.drop_constraint(op.f("ck_listings_pricing_model"), type_="check")
        batch.drop_column("minimum_price_cents")
        batch.drop_column("pricing_model")
