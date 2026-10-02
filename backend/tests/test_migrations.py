"""As migrações precisam produzir exatamente o banco que os modelos descrevem."""

from pathlib import Path
from typing import Any

import pytest
from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from sqlalchemy import Engine, inspect, select, text
from sqlalchemy.exc import IntegrityError

from app.core.database import create_db_engine
from app.models import Base
from app.modules.catalog.models import Category, EventType
from app.modules.catalog.reference_data import CATEGORIES, EVENT_TYPES

BACKEND_ROOT = Path(__file__).resolve().parent.parent


def alembic_config(url: str) -> Config:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_ROOT / "migrations"))
    config.set_main_option("sqlalchemy.url", url)
    return config


@pytest.fixture
def migrated(tmp_path: Path) -> Any:
    """Banco SQLite novo, criado só pelas migrações."""
    url = f"sqlite:///{(tmp_path / 'migrated.db').as_posix()}"
    command.upgrade(alembic_config(url), "head")
    engine = create_db_engine(url)
    yield engine, url
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


def test_migrated_schema_is_identical_to_the_models(migrated: Any, tmp_path: Path) -> None:
    migrated_engine, _ = migrated
    from_models = create_db_engine(f"sqlite:///{(tmp_path / 'models.db').as_posix()}")
    Base.metadata.create_all(from_models)
    try:
        expected = describe_schema(from_models)
        actual = describe_schema(migrated_engine)
    finally:
        from_models.dispose()

    assert set(actual) == set(expected)
    for table in expected:
        assert actual[table] == expected[table], f"tabela {table} diverge dos modelos"


def test_autogenerate_finds_nothing_pending(migrated: Any) -> None:
    engine, _ = migrated

    with engine.connect() as connection:
        context = MigrationContext.configure(connection, opts={"compare_type": True})
        pending = compare_metadata(context, Base.metadata)

    assert pending == []


def test_reference_data_matches_the_application_constants(migrated: Any) -> None:
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
        all_active = connection.execute(
            text("SELECT COUNT(*) FROM categories WHERE is_active = 0")
        ).scalar_one()

    assert categories == [dict(category) for category in CATEGORIES]
    assert event_types == [dict(event_type) for event_type in EVENT_TYPES]
    assert all_active == 0


def test_migrated_database_enforces_the_enum_checks(migrated: Any) -> None:
    engine, _ = migrated

    insert_party = (
        "INSERT INTO parties (id, owner_id, title, status, version, created_at, updated_at)"
        " VALUES (:id, 'u1', 'Festa', :status, 1, '2026-01-01', '2026-01-01')"
    )
    with engine.connect() as connection:
        connection.execute(
            text(
                "INSERT INTO users (id, email, password_hash, full_name, is_admin, is_active,"
                " token_version, terms_version, terms_accepted_at, created_at, updated_at)"
                " VALUES ('u1', 'a@b.c', 'x', 'Ana', 0, 1, 1, 'v', '2026-01-01', '2026-01-01',"
                " '2026-01-01')"
            )
        )
        # Um status válido entra; um inválido é barrado pelo CHECK.
        connection.execute(text(insert_party), {"id": "p1", "status": "planning"})
        with pytest.raises(IntegrityError):
            connection.execute(text(insert_party), {"id": "p2", "status": "status-invalido"})


def test_downgrade_removes_every_table(migrated: Any) -> None:
    engine, url = migrated

    command.downgrade(alembic_config(url), "base")

    assert set(inspect(engine).get_table_names()) <= {"alembic_version"}
