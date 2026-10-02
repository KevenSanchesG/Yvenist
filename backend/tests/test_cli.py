from collections.abc import Iterator
from datetime import timedelta
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import cli
from app.core.config import Settings
from app.core.database import create_db_engine, create_session_factory, utcnow
from app.main import create_app
from app.models import Base
from app.modules.accounts.models import RefreshToken, User
from app.modules.catalog.models import Listing
from tests.conftest import make_settings, seed_reference_data


@pytest.fixture
def cli_settings(tmp_path: Path) -> Settings:
    return make_settings(database_url=f"sqlite:///{(tmp_path / 'cli.db').as_posix()}")


@pytest.fixture
def session(cli_settings: Settings) -> Iterator[Session]:
    engine = create_db_engine(cli_settings.database_url)
    Base.metadata.create_all(engine)
    with create_session_factory(engine)() as db:
        seed_reference_data(db)
        yield db
    engine.dispose()


class TestCreateAdmin:
    def test_creates_an_admin_that_can_log_in(
        self,
        cli_settings: Settings,
        session: Session,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("YVENIST_ADMIN_PASSWORD", "senha-do-admin-123")

        exit_code = cli.main(["create-admin", "--email", "Admin@Example.com"], cli_settings)

        assert exit_code == 0
        assert "Administrador criado" in capsys.readouterr().out
        with TestClient(create_app(cli_settings)) as client:
            login = client.post(
                "/api/v1/auth/login",
                json={"email": "admin@example.com", "password": "senha-do-admin-123"},
            )
        assert login.status_code == 200
        assert login.json()["user"]["is_admin"] is True

    def test_promotes_an_existing_account_without_asking_for_a_password(
        self, cli_settings: Settings, session: Session, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.delenv("YVENIST_ADMIN_PASSWORD", raising=False)
        with TestClient(create_app(cli_settings)) as client:
            client.post(
                "/api/v1/auth/register",
                json={
                    "email": "ana@example.com",
                    "password": "senha-segura-123",
                    "full_name": "Ana Souza",
                    "accept_terms": True,
                },
            )

        exit_code = cli.main(["create-admin", "--email", "ana@example.com"], cli_settings)

        assert exit_code == 0
        stored = session.scalar(select(User).where(User.email == "ana@example.com"))
        assert stored is not None
        assert stored.is_admin is True

    def test_refuses_a_short_password(
        self,
        cli_settings: Settings,
        session: Session,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("YVENIST_ADMIN_PASSWORD", "curta")

        exit_code = cli.main(["create-admin", "--email", "admin@example.com"], cli_settings)

        assert exit_code == 1
        assert "pelo menos 8 caracteres" in capsys.readouterr().err
        assert session.scalar(select(func.count()).select_from(User)) == 0

    @pytest.mark.parametrize("email", ["admin@empresa.local", "admin@yvenist.test", "admin"])
    def test_refuses_an_email_the_login_would_reject(
        self,
        email: str,
        cli_settings: Settings,
        session: Session,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        # Regressão: o comando criava a conta, mas o login respondia 422 para
        # esses endereços e o administrador nunca conseguia entrar.
        monkeypatch.setenv("YVENIST_ADMIN_PASSWORD", "senha-do-admin-123")

        exit_code = cli.main(["create-admin", "--email", email], cli_settings)

        assert exit_code == 1
        assert "E-mail inválido" in capsys.readouterr().err
        assert session.scalar(select(func.count()).select_from(User)) == 0
        with TestClient(create_app(cli_settings)) as client:
            login = client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": "senha-do-admin-123"},
            )
        assert login.status_code == 422


class TestSeedDemo:
    def test_publishes_demo_listings_visible_in_the_catalog(
        self, cli_settings: Settings, session: Session
    ) -> None:
        assert cli.main(["seed-demo"], cli_settings) == 0

        with TestClient(create_app(cli_settings)) as client:
            venues = client.get("/api/v1/catalog/listings", params={"category": "venue"}).json()
            search = client.get("/api/v1/catalog/listings", params={"q": "salao glamour 3"})
        assert len(venues["items"]) == 8
        assert venues["items"][0]["title"] == "Salão Glamour 8"  # o mais avaliado primeiro
        assert [item["title"] for item in search.json()["items"]] == ["Salão Glamour 3"]

    def test_is_idempotent(
        self, cli_settings: Settings, session: Session, capsys: pytest.CaptureFixture[str]
    ) -> None:
        cli.main(["seed-demo"], cli_settings)
        first_total = session.scalar(select(func.count()).select_from(Listing))

        assert cli.main(["seed-demo"], cli_settings) == 0

        assert "já existem" in capsys.readouterr().out
        assert session.scalar(select(func.count()).select_from(Listing)) == first_total == 32

    def test_refuses_to_run_in_production(
        self, cli_settings: Settings, session: Session, capsys: pytest.CaptureFixture[str]
    ) -> None:
        production = make_settings(
            env="production",
            password_hash_profile="recommended",
            database_url=cli_settings.database_url,
        )

        assert cli.main(["seed-demo"], production) == 1
        assert "produção" in capsys.readouterr().err
        assert session.scalar(select(func.count()).select_from(Listing)) == 0


def test_purge_tokens_removes_only_old_sessions(
    cli_settings: Settings, session: Session, capsys: pytest.CaptureFixture[str]
) -> None:
    with TestClient(create_app(cli_settings)) as client:
        client.post(
            "/api/v1/auth/register",
            json={
                "email": "ana@example.com",
                "password": "senha-segura-123",
                "full_name": "Ana Souza",
                "accept_terms": True,
            },
        )
        client.post(
            "/api/v1/auth/login",
            json={"email": "ana@example.com", "password": "senha-segura-123"},
        )
    tokens = list(session.scalars(select(RefreshToken).order_by(RefreshToken.created_at)))
    tokens[0].expires_at = utcnow() - timedelta(days=45)
    session.commit()

    assert cli.main(["purge-tokens", "--older-than-days", "30"], cli_settings) == 0

    assert "1 sessões antigas removidas" in capsys.readouterr().out
    session.expire_all()
    remaining = list(session.scalars(select(RefreshToken)))
    assert [token.id for token in remaining] == [tokens[1].id]
