"""initial schema

Cria todas as tabelas da primeira versão da API e os dados de referência do
catálogo (categorias e tipos de evento).

Revision ID: 0001
Revises:
Create Date: 2026-10-02
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Colunas de enum são texto com CHECK dos valores válidos (sem tipo ENUM nativo):
# acrescentar um valor no futuro é só trocar a constraint.
ENUM = sa.String(length=32)
TIMESTAMP = sa.DateTime(timezone=True)

CATEGORIES = [
    {"slug": "venue", "name": "Salões", "icon": "venue", "sort_order": 10},
    {"slug": "attraction", "name": "Atrações", "icon": "attraction", "sort_order": 20},
    {"slug": "kids", "name": "Brinquedos", "icon": "kids", "sort_order": 30},
    {"slug": "buffet", "name": "Buffet e Bar", "icon": "buffet", "sort_order": 40},
    {"slug": "decoration", "name": "Decorações", "icon": "decoration", "sort_order": 50},
    {"slug": "beauty", "name": "Beleza", "icon": "beauty", "sort_order": 60},
    {"slug": "dj", "name": "DJ e Som", "icon": "dj", "sort_order": 70},
    {"slug": "staff", "name": "Equipe", "icon": "staff", "sort_order": 80},
    {"slug": "security", "name": "Segurança", "icon": "security", "sort_order": 90},
    {"slug": "other", "name": "Outros", "icon": "other", "sort_order": 100},
]

EVENT_TYPES = [
    {"slug": "wedding", "name": "Casamentos", "sort_order": 10},
    {"slug": "debutante", "name": "15 anos", "sort_order": 20},
    {"slug": "kids_party", "name": "Infantil", "sort_order": 30},
    {"slug": "corporate", "name": "Corporativo", "sort_order": 40},
    {"slug": "barbecue", "name": "Churrasco", "sort_order": 50},
    {"slug": "graduation", "name": "Formatura", "sort_order": 60},
]


def upgrade() -> None:
    categories = op.create_table(
        "categories",
        sa.Column("slug", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.Column("icon", sa.String(length=40), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("slug", name=op.f("pk_categories")),
    )
    event_types = op.create_table(
        "event_types",
        sa.Column("slug", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("slug", name=op.f("pk_event_types")),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("full_name", sa.String(length=120), nullable=False),
        sa.Column("phone", sa.String(length=20), nullable=True),
        sa.Column("birth_date", sa.Date(), nullable=True),
        sa.Column("is_admin", sa.Boolean(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("token_version", sa.Integer(), nullable=False),
        sa.Column("terms_version", sa.String(length=20), nullable=False),
        sa.Column("terms_accepted_at", TIMESTAMP, nullable=False),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.Column("updated_at", TIMESTAMP, nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_users")),
        sa.UniqueConstraint("email", name=op.f("uq_users_email")),
    )

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("family_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("user_agent", sa.String(length=255), nullable=True),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.Column("expires_at", TIMESTAMP, nullable=False),
        sa.Column("revoked_at", TIMESTAMP, nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_refresh_tokens_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_refresh_tokens")),
        sa.UniqueConstraint("token_hash", name=op.f("uq_refresh_tokens_token_hash")),
    )
    op.create_index(op.f("ix_refresh_tokens_user_id"), "refresh_tokens", ["user_id"])
    op.create_index(op.f("ix_refresh_tokens_family_id"), "refresh_tokens", ["family_id"])

    op.create_table(
        "vendor_profiles",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("person_type", ENUM, nullable=False),
        sa.Column("document", sa.String(length=14), nullable=False),
        sa.Column("legal_name", sa.String(length=160), nullable=False),
        sa.Column("status", ENUM, nullable=False),
        sa.Column("rejection_reason", sa.String(length=500), nullable=True),
        sa.Column("reviewed_at", TIMESTAMP, nullable=True),
        sa.Column("reviewed_by", sa.Uuid(), nullable=True),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.Column("updated_at", TIMESTAMP, nullable=False),
        sa.CheckConstraint(
            "person_type IN ('pf', 'pj')", name=op.f("ck_vendor_profiles_person_type")
        ),
        sa.CheckConstraint(
            "status IN ('pending_review', 'approved', 'rejected')",
            name=op.f("ck_vendor_profiles_vendor_status"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_vendor_profiles_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["reviewed_by"],
            ["users.id"],
            name=op.f("fk_vendor_profiles_reviewed_by_users"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_vendor_profiles")),
        sa.UniqueConstraint("user_id", name=op.f("uq_vendor_profiles_user_id")),
        sa.UniqueConstraint("document", name=op.f("uq_vendor_profiles_document")),
    )

    op.create_table(
        "listings",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("vendor_id", sa.Uuid(), nullable=False),
        sa.Column("category_slug", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("neighborhood", sa.String(length=80), nullable=True),
        sa.Column("city", sa.String(length=80), nullable=False),
        sa.Column("state", sa.String(length=2), nullable=False),
        sa.Column("price_from_cents", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("capacity", sa.Integer(), nullable=True),
        sa.Column("area_m2", sa.Integer(), nullable=True),
        sa.Column("amenities", sa.JSON(), nullable=False),
        sa.Column("cancellation_policy", ENUM, nullable=False),
        sa.Column("cover_image_url", sa.String(length=500), nullable=True),
        sa.Column("status", ENUM, nullable=False),
        sa.Column("rejection_reason", sa.String(length=500), nullable=True),
        sa.Column("rating_average", sa.Numeric(precision=3, scale=2), nullable=False),
        sa.Column("rating_count", sa.Integer(), nullable=False),
        sa.Column("search_text", sa.Text(), nullable=False),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.Column("updated_at", TIMESTAMP, nullable=False),
        sa.Column("published_at", TIMESTAMP, nullable=True),
        sa.CheckConstraint(
            "cancellation_policy IN ('flexible', 'moderate')",
            name=op.f("ck_listings_cancellation_policy"),
        ),
        sa.CheckConstraint(
            "status IN ('draft', 'pending_review', 'published', 'rejected', 'archived')",
            name=op.f("ck_listings_listing_status"),
        ),
        sa.CheckConstraint(
            "status <> 'published' OR published_at IS NOT NULL",
            name=op.f("ck_listings_published_has_date"),
        ),
        sa.CheckConstraint("price_from_cents >= 0", name=op.f("ck_listings_price_non_negative")),
        sa.CheckConstraint(
            "capacity IS NULL OR capacity > 0", name=op.f("ck_listings_capacity_positive")
        ),
        sa.CheckConstraint(
            "area_m2 IS NULL OR area_m2 > 0", name=op.f("ck_listings_area_positive")
        ),
        sa.CheckConstraint("rating_count >= 0", name=op.f("ck_listings_rating_count_non_negative")),
        sa.ForeignKeyConstraint(
            ["vendor_id"],
            ["vendor_profiles.id"],
            name=op.f("fk_listings_vendor_id_vendor_profiles"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["category_slug"],
            ["categories.slug"],
            name=op.f("fk_listings_category_slug_categories"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_listings")),
    )
    op.create_index(op.f("ix_listings_vendor_id"), "listings", ["vendor_id"])
    # Índices da vitrine: filtro por status + chave de ordenação + id (desempate
    # da paginação por cursor).
    op.create_index("ix_listings_status_rating_count", "listings", ["status", "rating_count", "id"])
    op.create_index("ix_listings_status_price", "listings", ["status", "price_from_cents", "id"])
    op.create_index("ix_listings_status_published_at", "listings", ["status", "published_at", "id"])
    op.create_index("ix_listings_status_category", "listings", ["status", "category_slug"])

    op.create_table(
        "listing_event_types",
        sa.Column("listing_id", sa.Uuid(), nullable=False),
        sa.Column("event_type_slug", sa.String(length=40), nullable=False),
        sa.ForeignKeyConstraint(
            ["listing_id"],
            ["listings.id"],
            name=op.f("fk_listing_event_types_listing_id_listings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["event_type_slug"],
            ["event_types.slug"],
            name=op.f("fk_listing_event_types_event_type_slug_event_types"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint(
            "listing_id", "event_type_slug", name=op.f("pk_listing_event_types")
        ),
    )
    op.create_index(
        "ix_listing_event_types_event_type_slug", "listing_event_types", ["event_type_slug"]
    )

    op.create_table(
        "favorites",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("listing_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_favorites_user_id_users"), ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["listing_id"],
            ["listings.id"],
            name=op.f("fk_favorites_listing_id_listings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("user_id", "listing_id", name=op.f("pk_favorites")),
    )
    op.create_index(op.f("ix_favorites_listing_id"), "favorites", ["listing_id"])

    op.create_table(
        "parties",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("owner_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.String(length=80), nullable=False),
        sa.Column("event_at", TIMESTAMP, nullable=True),
        sa.Column("guest_count", sa.Integer(), nullable=True),
        sa.Column("status", ENUM, nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("created_at", TIMESTAMP, nullable=False),
        sa.Column("updated_at", TIMESTAMP, nullable=False),
        sa.CheckConstraint(
            "status IN ('draft', 'planning', 'locked', 'paid', 'cancelled')",
            name=op.f("ck_parties_party_status"),
        ),
        sa.CheckConstraint(
            "guest_count IS NULL OR guest_count >= 1",
            name=op.f("ck_parties_guest_count_positive"),
        ),
        sa.ForeignKeyConstraint(
            ["owner_id"], ["users.id"], name=op.f("fk_parties_owner_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_parties")),
    )
    op.create_index("ix_parties_owner_id_updated_at", "parties", ["owner_id", "updated_at"])

    op.create_table(
        "party_items",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("party_id", sa.Uuid(), nullable=False),
        sa.Column("listing_id", sa.Uuid(), nullable=True),
        sa.Column("category", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("unit_price_cents", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("image_url", sa.String(length=500), nullable=True),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.CheckConstraint("quantity >= 1", name=op.f("ck_party_items_quantity_positive")),
        sa.CheckConstraint(
            "unit_price_cents >= 0", name=op.f("ck_party_items_unit_price_non_negative")
        ),
        sa.ForeignKeyConstraint(
            ["party_id"],
            ["parties.id"],
            name=op.f("fk_party_items_party_id_parties"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["listing_id"],
            ["listings.id"],
            name=op.f("fk_party_items_listing_id_listings"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_party_items")),
        sa.UniqueConstraint(
            "party_id", "listing_id", name=op.f("uq_party_items_party_id_listing_id")
        ),
    )
    op.create_index(op.f("ix_party_items_listing_id"), "party_items", ["listing_id"])
    # Regra "um salão por festa" garantida pelo banco (índice único parcial).
    op.create_index(
        "uq_party_items_one_venue_per_party",
        "party_items",
        ["party_id"],
        unique=True,
        sqlite_where=sa.text("category = 'venue'"),
        postgresql_where=sa.text("category = 'venue'"),
    )

    op.create_table(
        "party_snapshots",
        sa.Column("party_id", sa.Uuid(), nullable=False),
        sa.Column("generated_at", TIMESTAMP, nullable=False),
        sa.Column("expires_at", TIMESTAMP, nullable=True),
        sa.Column("total_cents", sa.BigInteger(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("breakdown", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(
            ["party_id"],
            ["parties.id"],
            name=op.f("fk_party_snapshots_party_id_parties"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("party_id", name=op.f("pk_party_snapshots")),
    )

    op.bulk_insert(categories, [{**category, "is_active": True} for category in CATEGORIES])
    op.bulk_insert(event_types, [{**event_type, "is_active": True} for event_type in EVENT_TYPES])


def downgrade() -> None:
    # Remove tudo: só faz sentido em um banco sem dados a preservar.
    op.drop_table("party_snapshots")
    op.drop_table("party_items")
    op.drop_table("parties")
    op.drop_table("favorites")
    op.drop_table("listing_event_types")
    op.drop_table("listings")
    op.drop_table("vendor_profiles")
    op.drop_table("refresh_tokens")
    op.drop_table("users")
    op.drop_table("event_types")
    op.drop_table("categories")
