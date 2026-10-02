"""Engine, sessão e tipos base do SQLAlchemy."""

from collections.abc import Iterator
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import DateTime, Dialect, Engine, Enum, MetaData, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker
from sqlalchemy.pool import StaticPool
from sqlalchemy.types import TypeDecorator

# Nomes determinísticos para índices e constraints: o Alembic precisa deles para
# conseguir alterar/remover constraints depois (inclusive em modo batch no SQLite).
NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    # column_0_N_name: todas as colunas entram no nome de uma constraint composta.
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

# Folga para acrescentar valores maiores depois sem alterar o tipo da coluna.
ENUM_COLUMN_LENGTH = 32


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


class UTCDateTime(TypeDecorator[datetime]):
    """Datetime sempre com fuso, gravado em UTC.

    O SQLite não guarda o fuso; sem este tipo as leituras voltariam "naive" e
    qualquer comparação com ``utcnow()`` levantaria ``TypeError``.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("datetime sem fuso horário não pode ser gravado.")
        return value.astimezone(UTC)

    def process_result_value(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


def utcnow() -> datetime:
    return datetime.now(UTC)


def str_enum(enum_class: type[StrEnum], *, name: str) -> Enum:
    """Coluna de enum gravada como texto, com CHECK dos valores válidos.

    Texto + CHECK (em vez do tipo ENUM nativo do PostgreSQL) mantém as
    migrações simples: acrescentar um valor é só trocar a constraint.
    """
    return Enum(
        enum_class,
        name=name,
        native_enum=False,
        create_constraint=True,
        validate_strings=True,
        values_callable=lambda members: [member.value for member in members],
        length=ENUM_COLUMN_LENGTH,
    )


def _enable_sqlite_foreign_keys(dbapi_connection: Any, _record: Any) -> None:
    # O SQLite só aplica chaves estrangeiras (e ON DELETE) se isso for ligado
    # em cada conexão.
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()


def create_db_engine(url: str, *, pool_size: int = 10, max_overflow: int = 20) -> Engine:
    if url.startswith("sqlite"):
        kwargs: dict[str, Any] = {"connect_args": {"check_same_thread": False}}
        if ":memory:" in url or url in {"sqlite://", "sqlite:///"}:
            # Banco em memória: uma única conexão compartilhada, senão cada
            # conexão veria um banco vazio diferente.
            kwargs["poolclass"] = StaticPool
        engine = create_engine(url, **kwargs)
        event.listen(engine, "connect", _enable_sqlite_foreign_keys)
        return engine

    return create_engine(
        url,
        pool_pre_ping=True,
        pool_size=pool_size,
        max_overflow=max_overflow,
    )


def create_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(bind=engine, expire_on_commit=False)


def session_scope(factory: sessionmaker[Session]) -> Iterator[Session]:
    """Abre uma sessão por requisição e desfaz o que não foi confirmado."""
    session = factory()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
