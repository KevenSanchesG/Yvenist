"""As migrações precisam produzir exatamente o banco que os modelos descrevem."""

import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
import sqlalchemy as sa
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import Engine, func, insert, inspect, literal_column, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.database import create_db_engine, utcnow
from app.models import Base
from app.modules.accounts.models import User
from app.modules.catalog.models import Category, EventType, Listing
from app.modules.catalog.pricing import PricingModel
from app.modules.catalog.reference_data import CATEGORIES, EVENT_TYPES
from app.modules.parties.domain import ItemRelation, QuoteStatus
from app.modules.parties.mapping import to_state
from app.modules.parties.models import Party, PartyItem
from app.modules.parties.service import WITH_CHILDREN
from tests.conftest import TEST_DATABASE_URL

BACKEND_ROOT = Path(__file__).resolve().parent.parent

Migrated = tuple[Engine, str]


def alembic_config(url: str) -> Config:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_ROOT / "migrations"))
    # "%" é caractere de interpolação nos arquivos .ini; uma senha codificada na
    # URL (%40 para "@", por exemplo) precisa dele dobrado.
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    return config


def drop_everything(engine: Engine) -> None:
    Base.metadata.drop_all(engine)
    with engine.begin() as connection:
        connection.execute(text("DROP TABLE IF EXISTS alembic_version"))


@pytest.fixture
def migrated(tmp_path: Path) -> Iterator[Migrated]:
    """Banco em que só as migrações rodaram.

    Em SQLite é um arquivo novo por teste. Com ``YVENIST_TEST_DATABASE_URL``
    (o CI usa PostgreSQL) é o próprio banco de testes, limpo antes e depois:
    as migrações têm de funcionar no banco de produção, não só no SQLite.
    """
    if TEST_DATABASE_URL.startswith("sqlite"):
        url = f"sqlite:///{(tmp_path / 'migrated.db').as_posix()}"
    else:
        url = TEST_DATABASE_URL
    engine = create_db_engine(url)
    drop_everything(engine)
    command.upgrade(alembic_config(url), "head")
    yield engine, url
    drop_everything(engine)
    engine.dispose()


def describe_schema(engine: Engine) -> dict[str, Any]:
    """Retrato comparável do esquema: colunas, chaves, índices e CHECKs."""
    inspector = inspect(engine)
    schema: dict[str, Any] = {}
    for table in sorted(inspector.get_table_names()):
        if table == "alembic_version":
            continue
        schema[table] = {
            "columns": {
                column["name"]: (str(column["type"]), column["nullable"])
                for column in inspector.get_columns(table)
            },
            "primary_key": inspector.get_pk_constraint(table)["constrained_columns"],
            "foreign_keys": sorted(
                (
                    tuple(fk["constrained_columns"]),
                    fk["referred_table"],
                    tuple(fk["referred_columns"]),
                    fk.get("options", {}).get("ondelete"),
                )
                for fk in inspector.get_foreign_keys(table)
            ),
            "unique": sorted(
                (constraint["name"], tuple(constraint["column_names"]))
                for constraint in inspector.get_unique_constraints(table)
            ),
            "indexes": sorted(
                (index["name"], tuple(index["column_names"]), bool(index["unique"]))
                for index in inspector.get_indexes(table)
            ),
            "checks": sorted(
                (check["name"], " ".join(check["sqltext"].split()))
                for check in inspector.get_check_constraints(table)
            ),
        }
    return schema


def test_migrated_schema_is_identical_to_the_models(migrated: Migrated) -> None:
    engine, _ = migrated
    actual = describe_schema(engine)

    # O mesmo banco, agora criado direto dos modelos.
    drop_everything(engine)
    Base.metadata.create_all(engine)
    expected = describe_schema(engine)

    assert expected, "os modelos não criaram nenhuma tabela"
    assert set(actual) == set(expected)
    for table in expected:
        assert actual[table] == expected[table], f"tabela {table} diverge dos modelos"


def test_autogenerate_finds_nothing_pending(migrated: Migrated) -> None:
    engine, _ = migrated

    with engine.connect() as connection:
        context = MigrationContext.configure(connection, opts={"compare_type": True})
        pending = compare_metadata(context, Base.metadata)

    assert pending == []


def test_reference_data_matches_the_application_constants(migrated: Migrated) -> None:
    engine, _ = migrated

    with engine.connect() as connection:
        categories = [
            dict(row._mapping)
            for row in connection.execute(
                select(Category.slug, Category.name, Category.icon, Category.sort_order).order_by(
                    Category.sort_order
                )
            )
        ]
        event_types = [
            dict(row._mapping)
            for row in connection.execute(
                select(EventType.slug, EventType.name, EventType.sort_order).order_by(
                    EventType.sort_order
                )
            )
        ]
        inactive = connection.execute(
            select(func.count()).select_from(Category).where(Category.is_active.is_(False))
        ).scalar_one()

    assert categories == [dict(category) for category in CATEGORIES]
    assert event_types == [dict(event_type) for event_type in EVENT_TYPES]
    assert inactive == 0


def test_migrated_database_enforces_the_enum_checks(migrated: Migrated) -> None:
    engine, _ = migrated
    owner_id = uuid.uuid4()
    now = utcnow()

    def party_with(status: str) -> Any:
        # literal_column manda o valor direto no SQL, sem passar pela validação
        # que o tipo Enum faz no Python: quem está sendo testado é o banco.
        return insert(Party).values(
            id=uuid.uuid4(),
            owner_id=owner_id,
            title="Festa",
            status=literal_column(f"'{status}'"),
            version=1,
            created_at=now,
            updated_at=now,
        )

    with engine.connect() as connection:
        connection.execute(
            insert(User).values(
                id=owner_id,
                email="ana@example.com",
                password_hash="x",
                full_name="Ana",
                is_admin=False,
                is_active=True,
                token_version=1,
                terms_version="v",
                terms_accepted_at=now,
                created_at=now,
                updated_at=now,
            )
        )
        # Um status válido entra; um inválido é barrado pelo CHECK.
        connection.execute(party_with("planning"))
        with pytest.raises(IntegrityError):
            connection.execute(party_with("status-invalido"))


def _old(table: str, *columns: sa.ColumnClause[Any]) -> sa.TableClause:
    """Uma tabela como ela era em uma migração anterior, só para inserir linhas."""
    return sa.table(table, *columns)


def _uuid(name: str) -> sa.ColumnClause[Any]:
    return sa.column(name, sa.Uuid())


def _time(name: str) -> sa.ColumnClause[Any]:
    return sa.column(name, sa.DateTime(timezone=True))


def test_existing_parties_are_carried_to_the_new_format(tmp_path: Path) -> None:
    """As migrações 0002 e 0003 não apagam nada: levam o que existe para o formato novo."""
    if TEST_DATABASE_URL.startswith("sqlite"):
        url = f"sqlite:///{(tmp_path / 'carried.db').as_posix()}"
    else:
        url = TEST_DATABASE_URL
    engine = create_db_engine(url)
    drop_everything(engine)
    config = alembic_config(url)
    now = utcnow()
    owner, vendor, venue, dj = (uuid.uuid4() for _ in range(4))
    requested, planned = uuid.uuid4(), uuid.uuid4()
    venue_item, dj_item, planned_item = (uuid.uuid4() for _ in range(3))

    try:
        # O banco como estava antes: só a primeira migração.
        command.upgrade(config, "0001")
        with engine.begin() as connection:
            connection.execute(
                insert(
                    _old(
                        "users",
                        _uuid("id"),
                        sa.column("email"),
                        sa.column("password_hash"),
                        sa.column("full_name"),
                        sa.column("is_admin"),
                        sa.column("is_active"),
                        sa.column("token_version"),
                        sa.column("terms_version"),
                        _time("terms_accepted_at"),
                        _time("created_at"),
                        _time("updated_at"),
                    )
                ).values(
                    id=owner,
                    email="ana@example.com",
                    password_hash="x",
                    full_name="Ana",
                    is_admin=False,
                    is_active=True,
                    token_version=1,
                    terms_version="v",
                    terms_accepted_at=now,
                    created_at=now,
                    updated_at=now,
                )
            )
            connection.execute(
                insert(
                    _old(
                        "vendor_profiles",
                        _uuid("id"),
                        _uuid("user_id"),
                        sa.column("person_type"),
                        sa.column("document"),
                        sa.column("legal_name"),
                        sa.column("status"),
                        _time("created_at"),
                        _time("updated_at"),
                    )
                ).values(
                    id=vendor,
                    user_id=owner,
                    person_type="pf",
                    document="52998224725",
                    legal_name="Ana",
                    status="approved",
                    created_at=now,
                    updated_at=now,
                )
            )
            listings = _old(
                "listings",
                _uuid("id"),
                _uuid("vendor_id"),
                sa.column("category_slug"),
                sa.column("title"),
                sa.column("description"),
                sa.column("city"),
                sa.column("state"),
                sa.column("price_from_cents"),
                sa.column("currency"),
                sa.column("amenities", sa.JSON()),
                sa.column("cancellation_policy"),
                sa.column("status"),
                sa.column("rating_average"),
                sa.column("rating_count"),
                sa.column("search_text"),
                _time("created_at"),
                _time("updated_at"),
                _time("published_at"),
            )
            for listing_id, category, title, price in (
                (venue, "venue", "Salão Glamour", 150_000),
                (dj, "dj", "DJ Festa Boa", 80_000),
            ):
                connection.execute(
                    insert(listings).values(
                        id=listing_id,
                        vendor_id=vendor,
                        category_slug=category,
                        title=title,
                        description="Anúncio de antes das formas de cobrança.",
                        city="Rio de Janeiro",
                        state="RJ",
                        price_from_cents=price,
                        currency="BRL",
                        amenities=[],
                        cancellation_policy="flexible",
                        status="published",
                        rating_average=0,
                        rating_count=0,
                        search_text=title.lower(),
                        created_at=now,
                        updated_at=now,
                        published_at=now,
                    )
                )
            parties = _old(
                "parties",
                _uuid("id"),
                _uuid("owner_id"),
                sa.column("title"),
                sa.column("status"),
                sa.column("version"),
                _time("created_at"),
                _time("updated_at"),
            )
            for party_id, title, status in (
                (requested, "Orçamento solicitado", "locked"),
                (planned, "Em planejamento", "planning"),
            ):
                connection.execute(
                    insert(parties).values(
                        id=party_id,
                        owner_id=owner,
                        title=title,
                        status=status,
                        version=1,
                        created_at=now,
                        updated_at=now,
                    )
                )
            items = _old(
                "party_items",
                _uuid("id"),
                _uuid("party_id"),
                _uuid("listing_id"),
                sa.column("category"),
                sa.column("name"),
                sa.column("unit_price_cents"),
                sa.column("currency"),
                sa.column("quantity"),
                sa.column("position"),
            )
            for item_id, party_id, listing_id, category, name, price, quantity, position in (
                (venue_item, requested, venue, "venue", "Salão Glamour", 150_000, 1, 0),
                # Duas unidades: a festa antiga somava preço vezes quantidade.
                (dj_item, requested, dj, "dj", "DJ Festa Boa", 80_000, 2, 1),
                (planned_item, planned, dj, "dj", "DJ Festa Boa", 80_000, 1, 0),
            ):
                connection.execute(
                    insert(items).values(
                        id=item_id,
                        party_id=party_id,
                        listing_id=listing_id,
                        category=category,
                        name=name,
                        unit_price_cents=price,
                        currency="BRL",
                        quantity=quantity,
                        position=position,
                    )
                )

        command.upgrade(config, "head")

        with Session(engine) as session:
            stored = {listing.id: listing for listing in session.scalars(select(Listing))}
            # O preço de um anúncio antigo era o valor do evento: valor fixo.
            assert {listing.pricing_model for listing in stored.values()} == {PricingModel.FIXED}
            assert stored[venue].price_from_cents == 150_000

            party = session.scalar(
                select(Party).where(Party.id == requested).options(*WITH_CHILDREN)
            )
            assert party is not None
            state = to_state(party)
            # O total de cada festa continua o mesmo: 1.500 + 2 x 800.
            assert state.estimate_cents == 310_000
            assert {item.pricing_model for item in state.items} == {PricingModel.PER_UNIT}
            assert {item.relation for item in state.items} == {ItemRelation.INDEPENDENT}
            assert all(item.configuration == {} for item in state.items)
            # O pedido vai para o dono do anúncio, e já estava esperando resposta.
            assert {item.vendor_id for item in state.items} == {vendor}
            assert {item.quote.status for item in state.items} == {QuoteStatus.PENDING}
            assert party.quote_round == 1

            other = session.scalar(select(Party).where(Party.id == planned).options(*WITH_CHILDREN))
            assert other is not None
            assert other.quote_round == 0
            assert other.items[0].quote_status is QuoteStatus.NONE

        # O índice de "um salão por festa" continua valendo só para os salões:
        # a festa com dois itens foi levada, e um segundo salão é barrado.
        with engine.connect() as connection:
            second_venue = insert(PartyItem).values(
                id=uuid.uuid4(),
                party_id=requested,
                category="venue",
                name="Outro salão",
                relation="independent",
                pricing_model="fixed",
                unit_price_cents=1,
                currency="BRL",
                quantity=1,
                configuration={},
                position=2,
                quote_status="none",
            )
            with pytest.raises(IntegrityError):
                connection.execute(second_venue)
    finally:
        drop_everything(engine)
        engine.dispose()


def test_downgrade_removes_every_table(migrated: Migrated) -> None:
    engine, url = migrated

    command.downgrade(alembic_config(url), "base")

    assert set(inspect(engine).get_table_names()) <= {"alembic_version"}
