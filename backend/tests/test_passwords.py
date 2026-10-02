"""Senhas muito comuns são recusadas no cadastro, na troca de senha e no CLI."""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import cli
from app.core.database import create_db_engine
from app.models import Base
from app.modules.accounts.models import User
from app.modules.accounts.passwords import (
    COMMON_PASSWORD_MESSAGE,
    COMMON_PASSWORDS,
    is_too_common,
)
from app.modules.accounts.schemas import PASSWORD_MIN_LENGTH
from tests.conftest import DEFAULT_PASSWORD, AuthenticatedUser, make_settings

REGISTER = "/api/v1/auth/register"
CHANGE_PASSWORD = "/api/v1/users/me/password"


def password_error(response) -> dict[str, str]:
    assert response.status_code == 422, response.text
    return {
        field["field"]: field["message"] for field in response.json()["error"]["details"]["fields"]
    }


class TestList:
    def test_every_entry_could_actually_be_typed_as_a_password(self) -> None:
        # Entradas mais curtas que o mínimo ou com maiúsculas nunca casariam
        # (a comparação é sem diferenciar caixa): seriam peso morto na lista.
        for password in COMMON_PASSWORDS:
            assert len(password) >= PASSWORD_MIN_LENGTH, password
            assert password == password.casefold(), password

    @pytest.mark.parametrize(
        "password",
        ["12345678", "Password123", " senha123 ", "QWERTYUIOP", "aaaaaaaaaa", "........"],
    )
    def test_recognizes_common_passwords_whatever_the_case(self, password: str) -> None:
        assert is_too_common(password) is True

    @pytest.mark.parametrize(
        "password",
        [DEFAULT_PASSWORD, "cavalo bateria grampo certo", "T9#kq!vz", "senha-da-ana-2026"],
    )
    def test_accepts_everything_else(self, password: str) -> None:
        assert is_too_common(password) is False


def test_registration_refuses_a_common_password(client: TestClient, db: Session) -> None:
    response = client.post(
        REGISTER,
        json={
            "email": "ana@example.com",
            "password": "Password123",
            "full_name": "Ana Souza",
            "accept_terms": True,
        },
    )

    assert password_error(response) == {"password": COMMON_PASSWORD_MESSAGE}
    assert db.scalar(select(func.count()).select_from(User)) == 0


def test_password_change_refuses_a_common_password(
    client: TestClient, user: AuthenticatedUser
) -> None:
    response = client.post(
        CHANGE_PASSWORD,
        headers=user.headers,
        json={"current_password": user.password, "new_password": "qwerty123"},
    )

    assert password_error(response) == {"new_password": COMMON_PASSWORD_MESSAGE}
    # A senha antiga continua valendo.
    login = client.post("/api/v1/auth/login", json={"email": user.email, "password": user.password})
    assert login.status_code == 200


def test_login_gives_no_hint_about_the_rule(client: TestClient, user: AuthenticatedUser) -> None:
    # A lista vale para senhas novas. Quem digita uma senha comum no login
    # recebe a mesma resposta de qualquer senha errada.
    response = client.post("/api/v1/auth/login", json={"email": user.email, "password": "12345678"})

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"


def test_cli_refuses_a_common_admin_password(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    settings = make_settings(database_url=f"sqlite:///{(tmp_path / 'cli.db').as_posix()}")
    engine = create_db_engine(settings.database_url)
    Base.metadata.create_all(engine)
    monkeypatch.setenv("YVENIST_ADMIN_PASSWORD", "admin1234")

    exit_code = cli.main(["create-admin", "--email", "admin@example.com"], settings)

    assert exit_code == 1
    assert "muito comum" in capsys.readouterr().err
    with engine.connect() as connection:
        assert connection.scalar(select(func.count()).select_from(User)) == 0
    engine.dispose()
