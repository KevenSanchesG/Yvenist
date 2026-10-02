"""As migrações precisam produzir exatamente o banco que os modelos descrevem."""

import uuid
from collections.abc import Iterator
from pathlib import Path
from typing import Any

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import Engine, func, insert, inspect, literal_column, select, text
from sqlalchemy.exc import IntegrityError

from app.core.database import create_db_engine, utcnow
from app.models import Base
from app.modules.accounts.models import User
from app.modules.catalog.models import Category, EventType
from app.modules.catalog.reference_data import CATEGORIES, EVENT_TYPES
from app.modules.parties.models import Party
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


def test_downgrade_removes_every_table(migrated: Migrated) -> None:
    engine, url = migrated

    command.downgrade(alembic_config(url), "base")

    assert set(inspect(engine).get_table_names()) <= {"alembic_version"}
