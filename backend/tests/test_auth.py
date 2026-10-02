import uuid
from datetime import timedelta

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import utcnow
from app.core.security import create_access_token
from app.main import create_app
from app.models import Base
from app.modules.accounts.models import RefreshToken, User
from tests.conftest import (
    DEFAULT_PASSWORD,
    TEST_JWT_SECRET,
    AuthenticatedUser,
    RegisterUser,
    make_settings,
)

REGISTER = "/api/v1/auth/register"
LOGIN = "/api/v1/auth/login"
REFRESH = "/api/v1/auth/refresh"
LOGOUT = "/api/v1/auth/logout"
ME = "/api/v1/users/me"


def register_payload(**overrides: object) -> dict[str, object]:
    payload: dict[str, object] = {
        "email": "ana@example.com",
        "password": DEFAULT_PASSWORD,
        "full_name": "Ana Souza",
        "accept_terms": True,
    }
    payload.update(overrides)
    return payload


def error_code(response) -> str:
    return response.json()["error"]["code"]


class TestRegister:
    def test_creates_the_account_and_starts_a_session(
        self, client: TestClient, db: Session
    ) -> None:
        response = client.post(REGISTER, json=register_payload())

        assert response.status_code == 201
        body = response.json()
        assert body["user"]["email"] == "ana@example.com"
        assert body["user"]["full_name"] == "Ana Souza"
        assert body["user"]["is_admin"] is False
        assert body["tokens"]["token_type"] == "bearer"
        assert body["tokens"]["expires_in"] == 15 * 60

        me = client.get(ME, headers={"Authorization": f"Bearer {body['tokens']['access_token']}"})
        assert me.status_code == 200
        assert me.json()["id"] == body["user"]["id"]

    def test_never_returns_or_stores_the_plain_password(
        self, client: TestClient, db: Session
    ) -> None:
        response = client.post(REGISTER, json=register_payload())

        assert DEFAULT_PASSWORD not in response.text
        assert "password" not in response.json()["user"]
        stored = db.scalar(select(User))
        assert stored is not None
        assert stored.password_hash.startswith("$argon2id$")

    def test_records_consent_to_the_terms(self, client: TestClient, db: Session) -> None:
        client.post(REGISTER, json=register_payload())

        stored = db.scalar(select(User))
        assert stored is not None
        assert stored.terms_version == "2026-10"
        assert stored.terms_accepted_at <= utcnow()

    def test_email_is_case_insensitive(self, client: TestClient) -> None:
        client.post(REGISTER, json=register_payload(email="Ana@Example.com"))

        duplicate = client.post(REGISTER, json=register_payload(email="ANA@example.COM"))

        assert duplicate.status_code == 409
        assert error_code(duplicate) == "email_already_registered"

    def test_cleans_up_the_name(self, client: TestClient) -> None:
        response = client.post(REGISTER, json=register_payload(full_name="  Ana   Souza  "))

        assert response.json()["user"]["full_name"] == "Ana Souza"

    @pytest.mark.parametrize(
        "overrides",
        [
            {"email": "nao-e-email"},
            {"password": "curta"},
            {"password": " " * 10},
            {"password": "x" * 129},
            {"full_name": "A"},
            {"accept_terms": False},
        ],
        ids=[
            "email inválido",
            "senha curta",
            "senha só de espaços",
            "senha longa demais",
            "nome curto",
            "termos não aceitos",
        ],
    )
    def test_rejects_invalid_data(self, client: TestClient, overrides: dict[str, object]) -> None:
        response = client.post(REGISTER, json=register_payload(**overrides))

        assert response.status_code == 422
        assert error_code(response) == "validation_error"

    def test_validation_errors_do_not_echo_the_password(self, client: TestClient) -> None:
        response = client.post(REGISTER, json=register_payload(password="curta", email="x"))

        assert "curta" not in response.text

    def test_cannot_make_itself_admin(self, client: TestClient, db: Session) -> None:
        # Campos que o cliente não deveria controlar são ignorados.
        response = client.post(
            REGISTER, json=register_payload(is_admin=True, token_version=99, is_active=False)
        )

        assert response.status_code == 201
        assert response.json()["user"]["is_admin"] is False
        stored = db.scalar(select(User))
        assert stored is not None
        assert stored.is_admin is False
        assert stored.is_active is True
        assert stored.token_version == 1


class TestLogin:
    def test_returns_a_new_session(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(LOGIN, json={"email": user.email, "password": user.password})

        assert response.status_code == 200
        body = response.json()
        assert body["user"]["id"] == str(user.id)
        assert body["tokens"]["refresh_token"] != user.refresh_token

    def test_email_is_case_insensitive(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(LOGIN, json={"email": user.email.upper(), "password": user.password})

        assert response.status_code == 200

    def test_wrong_password_and_unknown_email_look_the_same(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        wrong_password = client.post(LOGIN, json={"email": user.email, "password": "errada-123"})
        unknown_email = client.post(
            LOGIN, json={"email": "ninguem@example.com", "password": "errada-123"}
        )

        assert wrong_password.status_code == unknown_email.status_code == 401
        assert wrong_password.json()["error"]["message"] == unknown_email.json()["error"]["message"]
        assert error_code(wrong_password) == error_code(unknown_email) == "invalid_credentials"

    def test_inactive_account_cannot_login(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        stored = db.get_one(User, user.id)
        stored.is_active = False
        db.commit()

        response = client.post(LOGIN, json={"email": user.email, "password": user.password})

        assert response.status_code == 401
        assert error_code(response) == "invalid_credentials"


class TestAccessToken:
    def test_protected_route_requires_a_token(self, client: TestClient) -> None:
        response = client.get(ME)

        assert response.status_code == 401
        assert error_code(response) == "unauthorized"
        assert response.headers["www-authenticate"] == "Bearer"

    @pytest.mark.parametrize("token", ["lixo", "a.b.c", ""])
    def test_rejects_malformed_tokens(self, client: TestClient, token: str) -> None:
        response = client.get(ME, headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 401

    def test_rejects_expired_token(self, client: TestClient, user: AuthenticatedUser) -> None:
        token, _ = create_access_token(
            user_id=user.id,
            token_version=1,
            secret=TEST_JWT_SECRET,
            ttl=timedelta(minutes=15),
            now=utcnow() - timedelta(hours=1),
        )

        response = client.get(ME, headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 401
        assert error_code(response) == "invalid_token"

    def test_rejects_token_forged_with_another_secret(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        token, _ = create_access_token(
            user_id=user.id,
            token_version=1,
            secret="segredo-do-atacante-com-32-caracteres!!",
            ttl=timedelta(minutes=15),
        )

        response = client.get(ME, headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 401

    def test_rejects_token_of_a_deleted_account(self, client: TestClient) -> None:
        token, _ = create_access_token(
            user_id=uuid.uuid4(),
            token_version=1,
            secret=TEST_JWT_SECRET,
            ttl=timedelta(minutes=15),
        )

        response = client.get(ME, headers={"Authorization": f"Bearer {token}"})

        assert response.status_code == 401

    def test_rejects_token_of_a_deactivated_account(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        db.get_one(User, user.id).is_active = False
        db.commit()

        assert client.get(ME, headers=user.headers).status_code == 401


class TestRefresh:
    def test_rotates_the_refresh_token(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(REFRESH, json={"refresh_token": user.refresh_token})

        assert response.status_code == 200
        tokens = response.json()["tokens"]
        assert tokens["refresh_token"] != user.refresh_token
        me = client.get(ME, headers={"Authorization": f"Bearer {tokens['access_token']}"})
        assert me.status_code == 200

    def test_reusing_a_rotated_token_ends_the_whole_session(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        rotated = client.post(REFRESH, json={"refresh_token": user.refresh_token}).json()
        new_refresh_token = rotated["tokens"]["refresh_token"]

        # O token antigo reaparece: sinal de que foi copiado por alguém.
        reuse = client.post(REFRESH, json={"refresh_token": user.refresh_token})

        assert reuse.status_code == 401
        assert error_code(reuse) == "invalid_refresh_token"
        # O token legítimo, emitido na rotação, também deixa de valer.
        assert client.post(REFRESH, json={"refresh_token": new_refresh_token}).status_code == 401

    def test_rejects_unknown_token(self, client: TestClient) -> None:
        response = client.post(REFRESH, json={"refresh_token": "x" * 40})

        assert response.status_code == 401

    def test_rejects_expired_token(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        stored = db.scalar(select(RefreshToken))
        assert stored is not None
        stored.expires_at = utcnow() - timedelta(seconds=1)
        db.commit()

        response = client.post(REFRESH, json={"refresh_token": user.refresh_token})

        assert response.status_code == 401

    def test_only_the_hash_of_the_token_is_stored(
        self, user: AuthenticatedUser, db: Session
    ) -> None:
        stored = db.scalar(select(RefreshToken))

        assert stored is not None
        assert stored.token_hash != user.refresh_token
        assert user.refresh_token not in stored.token_hash

    def test_sessions_of_other_devices_are_not_affected(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        other_device = client.post(
            LOGIN, json={"email": user.email, "password": user.password}
        ).json()["tokens"]["refresh_token"]
        client.post(REFRESH, json={"refresh_token": user.refresh_token})
        client.post(REFRESH, json={"refresh_token": user.refresh_token})  # reuso

        response = client.post(REFRESH, json={"refresh_token": other_device})

        assert response.status_code == 200


class TestLogout:
    def test_ends_the_session(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(LOGOUT, json={"refresh_token": user.refresh_token})

        assert response.status_code == 204
        assert client.post(REFRESH, json={"refresh_token": user.refresh_token}).status_code == 401

    def test_is_idempotent(self, client: TestClient, user: AuthenticatedUser) -> None:
        client.post(LOGOUT, json={"refresh_token": user.refresh_token})

        assert client.post(LOGOUT, json={"refresh_token": user.refresh_token}).status_code == 204
        assert client.post(LOGOUT, json={"refresh_token": "y" * 40}).status_code == 204


class TestRateLimit:
    @pytest.fixture
    def limited_app(self) -> FastAPI:
        application = create_app(
            make_settings(
                rate_limit_enabled=True,
                login_rate_limit_per_minute=3,
                register_rate_limit_per_minute=2,
            )
        )
        Base.metadata.create_all(application.state.engine)
        return application

    def test_login_is_blocked_after_too_many_attempts(self, limited_app: FastAPI) -> None:
        with TestClient(limited_app) as client:
            credentials = {"email": "ana@example.com", "password": "errada-123"}
            statuses = [client.post(LOGIN, json=credentials).status_code for _ in range(4)]

            assert statuses == [401, 401, 401, 429]
            blocked = client.post(LOGIN, json=credentials)
            assert error_code(blocked) == "too_many_requests"
            assert int(blocked.headers["retry-after"]) >= 1

    def test_register_is_blocked_after_too_many_attempts(self, limited_app: FastAPI) -> None:
        with TestClient(limited_app) as client:
            statuses = [
                client.post(REGISTER, json=register_payload(email=f"u{i}@example.com")).status_code
                for i in range(3)
            ]

            assert statuses == [201, 201, 429]


def test_two_registrations_issue_independent_sessions(register_user: RegisterUser) -> None:
    first = register_user()
    second = register_user()

    assert first.id != second.id
    assert first.access_token != second.access_token
