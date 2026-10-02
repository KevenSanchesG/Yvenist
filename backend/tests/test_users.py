import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.accounts.models import RefreshToken, User
from app.modules.favorites.models import Favorite
from app.modules.parties.models import Party
from tests.conftest import AuthenticatedUser, CreateListing

ME = "/api/v1/users/me"
PASSWORD = "/api/v1/users/me/password"
DELETE = "/api/v1/users/me/delete"
SESSIONS = "/api/v1/users/me/sessions"
LOGIN = "/api/v1/auth/login"
REFRESH = "/api/v1/auth/refresh"


def error_code(response) -> str:
    return response.json()["error"]["code"]


class TestProfile:
    def test_returns_the_authenticated_user(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.get(ME, headers=user.headers)

        assert response.status_code == 200
        assert response.json() == {
            "id": str(user.id),
            "email": user.email,
            "full_name": "Ana Souza",
            "phone": None,
            "birth_date": None,
            "is_admin": False,
            "created_at": response.json()["created_at"],
        }

    def test_updates_only_the_fields_sent(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        client.patch(ME, headers=user.headers, json={"phone": "(21) 99999-8888"})

        response = client.patch(ME, headers=user.headers, json={"full_name": "Ana Maria Souza"})

        assert response.status_code == 200
        body = response.json()
        assert body["full_name"] == "Ana Maria Souza"
        assert body["phone"] == "21999998888"

    def test_clears_optional_fields_with_null(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        client.patch(
            ME, headers=user.headers, json={"phone": "21999998888", "birth_date": "1995-05-20"}
        )

        response = client.patch(ME, headers=user.headers, json={"phone": None, "birth_date": None})

        assert response.json()["phone"] is None
        assert response.json()["birth_date"] is None

    @pytest.mark.parametrize(
        "payload",
        [
            {"full_name": None},
            {"full_name": " "},
            {"phone": "123"},
            {"birth_date": "2999-01-01"},
            {"birth_date": "1800-01-01"},
        ],
    )
    def test_rejects_invalid_data(
        self, client: TestClient, user: AuthenticatedUser, payload: dict[str, object]
    ) -> None:
        response = client.patch(ME, headers=user.headers, json=payload)

        assert response.status_code == 422

    def test_cannot_change_privileged_or_identity_fields(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        response = client.patch(
            ME,
            headers=user.headers,
            json={"is_admin": True, "email": "outro@example.com", "password_hash": "x"},
        )

        assert response.status_code == 200
        stored = db.get_one(User, user.id)
        assert stored.is_admin is False
        assert stored.email == user.email
        assert stored.password_hash != "x"


class TestChangePassword:
    def test_changes_the_password_and_returns_a_new_session(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.post(
            PASSWORD,
            headers=user.headers,
            json={"current_password": user.password, "new_password": "nova-senha-456"},
        )

        assert response.status_code == 200
        new_headers = {"Authorization": f"Bearer {response.json()['access_token']}"}
        assert client.get(ME, headers=new_headers).status_code == 200
        login = client.post(LOGIN, json={"email": user.email, "password": "nova-senha-456"})
        assert login.status_code == 200
        old_login = client.post(LOGIN, json={"email": user.email, "password": user.password})
        assert old_login.status_code == 401

    def test_invalidates_every_previous_session_immediately(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        client.post(
            PASSWORD,
            headers=user.headers,
            json={"current_password": user.password, "new_password": "nova-senha-456"},
        )

        # Nem o token de acesso antigo (ainda dentro da validade) nem o de
        # renovação continuam valendo.
        assert client.get(ME, headers=user.headers).status_code == 401
        assert client.post(REFRESH, json={"refresh_token": user.refresh_token}).status_code == 401

    def test_requires_the_current_password(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.post(
            PASSWORD,
            headers=user.headers,
            json={"current_password": "errada-123", "new_password": "nova-senha-456"},
        )

        assert response.status_code == 422
        assert error_code(response) == "wrong_password"
        assert client.get(ME, headers=user.headers).status_code == 200

    def test_validates_the_new_password(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(
            PASSWORD,
            headers=user.headers,
            json={"current_password": user.password, "new_password": "curta"},
        )

        assert response.status_code == 422


class TestDeleteAccount:
    def test_removes_the_account_and_everything_it_owns(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        db: Session,
        create_listing: CreateListing,
    ) -> None:
        listing = create_listing()
        client.put(f"/api/v1/favorites/{listing.id}", headers=user.headers)
        client.put(
            "/api/v1/parties/11111111-1111-1111-1111-111111111111",
            headers=user.headers,
            json={"title": "Festa", "status": "planning", "items": []},
        )

        response = client.post(DELETE, headers=user.headers, json={"password": user.password})

        assert response.status_code == 204
        db.expire_all()
        assert db.get(User, user.id) is None
        assert db.scalar(select(func.count()).select_from(Favorite)) == 0
        assert db.scalar(select(func.count()).select_from(Party)) == 0
        assert (
            db.scalar(
                select(func.count())
                .select_from(RefreshToken)
                .where(RefreshToken.user_id == user.id)
            )
            == 0
        )
        assert client.get(ME, headers=user.headers).status_code == 401
        login = client.post(LOGIN, json={"email": user.email, "password": user.password})
        assert login.status_code == 401

    def test_requires_the_password(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        response = client.post(DELETE, headers=user.headers, json={"password": "errada-123"})

        assert response.status_code == 422
        assert error_code(response) == "wrong_password"
        assert db.get(User, user.id) is not None

    def test_does_not_touch_other_accounts(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        other_user: AuthenticatedUser,
    ) -> None:
        client.post(DELETE, headers=user.headers, json={"password": user.password})

        assert client.get(ME, headers=other_user.headers).status_code == 200


class TestSessions:
    def test_lists_the_active_sessions(self, client: TestClient, user: AuthenticatedUser) -> None:
        client.post(
            LOGIN,
            json={"email": user.email, "password": user.password},
            headers={"User-Agent": "Yvenist/1.0 (Android)"},
        )

        response = client.get(SESSIONS, headers=user.headers)

        assert response.status_code == 200
        sessions = response.json()
        assert len(sessions) == 2
        assert sessions[0]["user_agent"] == "Yvenist/1.0 (Android)"
        assert "token_hash" not in sessions[0]

    def test_revoking_a_session_ends_only_that_device(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        other_device = client.post(
            LOGIN, json={"email": user.email, "password": user.password}
        ).json()["tokens"]["refresh_token"]
        sessions = client.get(SESSIONS, headers=user.headers).json()
        newest = sessions[0]["id"]

        response = client.delete(f"{SESSIONS}/{newest}", headers=user.headers)

        assert response.status_code == 204
        assert client.post(REFRESH, json={"refresh_token": other_device}).status_code == 401
        assert client.post(REFRESH, json={"refresh_token": user.refresh_token}).status_code == 200

    def test_cannot_see_or_revoke_sessions_of_another_user(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        other_user: AuthenticatedUser,
    ) -> None:
        victim_session = client.get(SESSIONS, headers=user.headers).json()[0]["id"]

        response = client.delete(f"{SESSIONS}/{victim_session}", headers=other_user.headers)

        assert response.status_code == 404
        assert error_code(response) == "session_not_found"
        assert client.post(REFRESH, json={"refresh_token": user.refresh_token}).status_code == 200
        assert len(client.get(SESSIONS, headers=other_user.headers).json()) == 1
