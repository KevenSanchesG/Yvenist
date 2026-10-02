"""Infraestrutura dos testes: app em memória, clientes HTTP e fábricas de dados."""

import os
import uuid
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.database import utcnow
from app.main import create_app
from app.models import Base
from app.modules.accounts.models import User
from app.modules.catalog.models import Category, EventType, Listing, ListingStatus
from app.modules.catalog.reference_data import CATEGORIES, EVENT_TYPES
from app.modules.catalog.text import build_search_text
from app.modules.vendors.models import PersonType, VendorProfile, VendorStatus

TEST_JWT_SECRET = "test-secret-with-at-least-32-characters!!"
DEFAULT_PASSWORD = "senha-segura-123"

# Por padrão os testes usam SQLite em memória. Para rodar a mesma suíte contra
# outro banco (o CI usa PostgreSQL), defina YVENIST_TEST_DATABASE_URL.
TEST_DATABASE_URL = os.environ.get("YVENIST_TEST_DATABASE_URL", "sqlite://")


def make_settings(**overrides: Any) -> Settings:
    values: dict[str, Any] = {
        "env": "test",
        "database_url": TEST_DATABASE_URL,
        "jwt_secret": TEST_JWT_SECRET,
        "password_hash_profile": "test",
        "rate_limit_enabled": False,
        "log_level": "WARNING",
    }
    values.update(overrides)
    # _env_file=None: os testes não podem depender de um .env local.
    return Settings(_env_file=None, **values)


@pytest.fixture
def settings() -> Settings:
    return make_settings()


@pytest.fixture
def app(settings: Settings) -> Iterator[FastAPI]:
    application = create_app(settings)
    engine = application.state.engine
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with application.state.session_factory() as session:
        seed_reference_data(session)
    yield application
    Base.metadata.drop_all(engine)
    engine.dispose()


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture
def db(app: FastAPI, client: TestClient) -> Iterator[Session]:
    """Sessão direta no banco do teste, para preparar e conferir dados.

    Depende de ``client`` só pela ordem de encerramento: a sessão precisa fechar
    antes de o cliente desligar a aplicação, que descarta o pool de conexões.
    Fechada depois, a conexão dela ficava presa no pool descartado e só era
    encerrada pelo coletor de lixo (o PostgreSQL acusa isso; o SQLite não).
    """
    with app.state.session_factory() as session:
        yield session


def seed_reference_data(session: Session) -> None:
    session.add_all(Category(**category) for category in CATEGORIES)
    session.add_all(EventType(**event_type) for event_type in EVENT_TYPES)
    session.commit()


# ----------------------------------------------------------------------
# Usuários autenticados
# ----------------------------------------------------------------------


@dataclass
class AuthenticatedUser:
    id: uuid.UUID
    email: str
    password: str
    access_token: str
    refresh_token: str

    @property
    def headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.access_token}"}


RegisterUser = Callable[..., AuthenticatedUser]


@pytest.fixture
def register_user(client: TestClient) -> RegisterUser:
    counter = 0

    def _register(
        email: str | None = None,
        password: str = DEFAULT_PASSWORD,
        full_name: str = "Ana Souza",
    ) -> AuthenticatedUser:
        nonlocal counter
        counter += 1
        email = email or f"usuario{counter}@example.com"
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": password,
                "full_name": full_name,
                "accept_terms": True,
            },
        )
        assert response.status_code == 201, response.text
        body = response.json()
        return AuthenticatedUser(
            id=uuid.UUID(body["user"]["id"]),
            email=body["user"]["email"],
            password=password,
            access_token=body["tokens"]["access_token"],
            refresh_token=body["tokens"]["refresh_token"],
        )

    return _register


@pytest.fixture
def user(register_user: RegisterUser) -> AuthenticatedUser:
    return register_user()


@pytest.fixture
def other_user(register_user: RegisterUser) -> AuthenticatedUser:
    return register_user()


@pytest.fixture
def admin(register_user: RegisterUser, db: Session) -> AuthenticatedUser:
    account = register_user(email="admin@example.com")
    stored = db.get(User, account.id)
    assert stored is not None
    stored.is_admin = True
    db.commit()
    return account


# ----------------------------------------------------------------------
# Catálogo
# ----------------------------------------------------------------------

CreateListing = Callable[..., Listing]

# CPFs válidos, só para os testes.
VALID_CPFS = ("52998224725", "11144477735", "39053344705", "86288366757")
VALID_CNPJ = "11222333000181"
VALID_ALPHANUMERIC_CNPJ = "12ABC34501DE35"


@pytest.fixture
def vendor_profile(db: Session, register_user: RegisterUser) -> VendorProfile:
    """Um fornecedor aprovado, dono dos anúncios criados por ``create_listing``."""
    owner = register_user(email="fornecedor@example.com", full_name="Fornecedor Teste")
    profile = VendorProfile(
        user_id=owner.id,
        person_type=PersonType.INDIVIDUAL,
        document=VALID_CPFS[0],
        legal_name="Fornecedor Teste",
        status=VendorStatus.APPROVED,
    )
    db.add(profile)
    db.commit()
    return profile


@pytest.fixture
def create_listing(db: Session, vendor_profile: VendorProfile) -> CreateListing:
    counter = 0

    def _create(
        *,
        title: str | None = None,
        category: str = "venue",
        price_from_cents: int = 100_000,
        status: ListingStatus = ListingStatus.PUBLISHED,
        rating_count: int = 0,
        event_types: tuple[str, ...] = (),
        neighborhood: str | None = "Campo Grande",
        city: str = "Rio de Janeiro",
        state: str = "RJ",
        published_minutes_ago: int = 0,
    ) -> Listing:
        nonlocal counter
        counter += 1
        title = title or f"Salão Glamour {counter}"
        category_name = next(c["name"] for c in CATEGORIES if c["slug"] == category)
        listing = Listing(
            vendor_id=vendor_profile.id,
            category_slug=category,
            title=title,
            description="Espaço completo para a sua festa, com tudo o que você precisa.",
            neighborhood=neighborhood,
            city=city,
            state=state,
            price_from_cents=price_from_cents,
            cover_image_url="https://example.com/capa.jpg",
            status=status,
            rating_average=Decimal("4.80"),
            rating_count=rating_count,
            search_text=build_search_text(title, neighborhood, city, state, category_name),
            published_at=(
                utcnow() - timedelta(minutes=published_minutes_ago)
                if status is ListingStatus.PUBLISHED
                else None
            ),
            event_types=[db.get_one(EventType, slug) for slug in event_types],
        )
        db.add(listing)
        db.commit()
        return listing

    return _create
