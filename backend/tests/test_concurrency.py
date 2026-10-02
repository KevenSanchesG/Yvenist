"""Requisições simultâneas de verdade.

As verificações do tipo "já existe?" seguidas de uma gravação só são seguras se
o banco tiver a última palavra: entre a pergunta e a gravação, outra requisição
pode ter passado na frente. Aqui várias chamadas iguais saem ao mesmo tempo e o
resultado precisa ser o mesmo de chamadas em fila, nunca um erro 500.

Só fazem sentido em um banco com concorrência real: o SQLite em memória dos
testes usa uma única conexão. Rodam quando ``YVENIST_TEST_DATABASE_URL`` aponta
para o PostgreSQL, que é o caso do CI.
"""

import threading
import uuid
from collections import Counter
from collections.abc import Callable, Sequence
from concurrent.futures import ThreadPoolExecutor
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.accounts.models import User
from app.modules.catalog.models import Listing
from app.modules.favorites.models import Favorite
from app.modules.parties.models import Party, PartyItem
from app.modules.vendors.models import VendorProfile
from tests.conftest import (
    TEST_DATABASE_URL,
    VALID_CPFS,
    AuthenticatedUser,
    CreateListing,
    RegisterUser,
)

pytestmark = pytest.mark.skipif(
    TEST_DATABASE_URL.startswith("sqlite"),
    reason="exige concorrência real: defina YVENIST_TEST_DATABASE_URL com um PostgreSQL",
)

PARALLEL = 8

REGISTER = "/api/v1/auth/register"
REFRESH = "/api/v1/auth/refresh"
FAVORITES = "/api/v1/favorites"
PARTIES = "/api/v1/parties"
ONBOARDING = "/api/v1/vendors/onboarding"
ADMIN_VENDORS = "/api/v1/admin/vendors"

Call = Callable[[], Any]


def in_parallel(calls: Sequence[Call]) -> list[Any]:
    """Dispara todas as chamadas no mesmo instante e devolve as respostas."""
    barrier = threading.Barrier(len(calls))

    def run(call: Call) -> Any:
        barrier.wait(timeout=10)
        return call()

    with ThreadPoolExecutor(max_workers=len(calls)) as pool:
        return list(pool.map(run, calls))


@pytest.fixture(autouse=True)
def warm_connection_pool(client: TestClient) -> None:
    """Abre as conexões do pool antes de cada teste.

    Sem isso, a primeira rodada simultânea gasta o tempo abrindo conexões, as
    chamadas saem escalonadas e a corrida que o teste quer provocar não acontece
    (ele passaria mesmo com o defeito presente).
    """
    in_parallel([lambda: client.get("/health/ready")] * PARALLEL)


def statuses(responses: Sequence[Any]) -> Counter[int]:
    return Counter(response.status_code for response in responses)


def error_codes(responses: Sequence[Any], status: int) -> set[str]:
    return {
        response.json()["error"]["code"] for response in responses if response.status_code == status
    }


def count(db: Session, model: type) -> int:
    return db.scalar(select(func.count()).select_from(model)) or 0


def onboarding_body(document: str = VALID_CPFS[1]) -> dict[str, Any]:
    return {
        "vendor": {"person_type": "pf", "document": document, "legal_name": "Maria Oliveira"},
        "listing": {
            "category": "venue",
            "title": "Espaço Crystal",
            "description": "Salão amplo, climatizado, com cozinha equipada e área kids.",
            "city": "Rio de Janeiro",
            "state": "RJ",
            "price_from_cents": 250_000,
            "event_types": ["wedding"],
        },
    }


class TestAccounts:
    def test_one_email_registered_at_once_creates_one_account(
        self, client: TestClient, db: Session
    ) -> None:
        payload = {
            "email": "ana@example.com",
            "password": "senha-segura-123",
            "full_name": "Ana Souza",
            "accept_terms": True,
        }

        responses = in_parallel([lambda: client.post(REGISTER, json=payload)] * PARALLEL)

        assert statuses(responses) == {201: 1, 409: PARALLEL - 1}
        assert error_codes(responses, 409) == {"email_already_registered"}
        assert count(db, User) == 1

    def test_one_refresh_token_used_at_once_rotates_only_once(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        body = {"refresh_token": user.refresh_token}

        responses = in_parallel([lambda: client.post(REFRESH, json=body)] * PARALLEL)

        # Sem a trava na linha do token, duas chamadas trocariam o mesmo token e
        # sairiam com duas sessões válidas a partir de uma.
        assert statuses(responses) == {200: 1, 401: PARALLEL - 1}
        # As demais tentativas contam como reuso: a sessão inteira é encerrada,
        # inclusive o token que acabou de ser emitido.
        winner = next(response for response in responses if response.status_code == 200)
        newest = winner.json()["tokens"]["refresh_token"]
        assert client.post(REFRESH, json={"refresh_token": newest}).status_code == 401


class TestFavorites:
    def test_one_favorite_added_at_once_is_stored_once(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        db: Session,
    ) -> None:
        url = f"{FAVORITES}/{create_listing().id}"

        responses = in_parallel([lambda: client.put(url, headers=user.headers)] * PARALLEL)

        assert statuses(responses) == {204: PARALLEL}
        assert count(db, Favorite) == 1


class TestParties:
    def test_one_party_created_at_once_exists_once(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        db: Session,
    ) -> None:
        url = f"{PARTIES}/{uuid.uuid4()}"
        body = {
            "title": "Casamento",
            "status": "planning",
            "items": [
                {"id": str(uuid.uuid4()), "listing_id": str(create_listing().id), "quantity": 1}
            ],
        }

        responses = in_parallel(
            [lambda: client.put(url, headers=user.headers, json=body)] * PARALLEL
        )

        # Uma cria. As outras ou perdem a corrida (409) ou chegam depois e
        # encontram a festa já igual ao que pediram (200, sem gravar de novo).
        outcome = statuses(responses)
        assert outcome[201] == 1
        assert set(outcome) <= {200, 201, 409}
        assert error_codes(responses, 409) <= {"party_id_conflict"}
        assert count(db, Party) == 1
        assert count(db, PartyItem) == 1

    def test_edits_of_one_version_at_once_do_not_overwrite_each_other(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
    ) -> None:
        url = f"{PARTIES}/{uuid.uuid4()}"
        venue_item = {
            "id": str(uuid.uuid4()),
            "listing_id": str(create_listing().id),
            "quantity": 1,
        }
        extras = [
            str(create_listing(category="attraction", title=f"Atração {index}").id)
            for index in range(PARALLEL)
        ]
        created = client.put(
            url,
            headers=user.headers,
            json={"title": "Casamento", "status": "planning", "items": [venue_item]},
        )
        assert created.status_code == 201
        version = created.json()["version"]

        def add(listing_id: str) -> Call:
            # Cada aparelho acrescenta um item diferente partindo da mesma versão.
            body = {
                "title": "Casamento",
                "status": "planning",
                "version": version,
                "items": [
                    venue_item,
                    {"id": str(uuid.uuid4()), "listing_id": listing_id, "quantity": 1},
                ],
            }
            return lambda: client.put(url, headers=user.headers, json=body)

        responses = in_parallel([add(listing_id) for listing_id in extras])

        assert statuses(responses) == {200: 1, 409: PARALLEL - 1}
        assert error_codes(responses, 409) == {"party_version_conflict"}
        stored = client.get(url, headers=user.headers).json()
        assert len(stored["items"]) == 2
        assert stored["version"] == version + 1


class TestVendors:
    def test_one_document_submitted_by_several_accounts_at_once(
        self, client: TestClient, register_user: RegisterUser, db: Session
    ) -> None:
        accounts = [register_user() for _ in range(PARALLEL)]

        def submit(account: AuthenticatedUser) -> Call:
            return lambda: client.post(ONBOARDING, headers=account.headers, json=onboarding_body())

        responses = in_parallel([submit(account) for account in accounts])

        assert statuses(responses) == {201: 1, 409: PARALLEL - 1}
        assert error_codes(responses, 409) == {"document_already_registered"}
        assert count(db, VendorProfile) == 1
        assert count(db, Listing) == 1

    def test_double_submission_by_one_account_keeps_a_single_profile(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        # Dois toques seguidos em "Enviar anúncio", ou uma tentativa repetida
        # depois de a primeira resposta se perder.
        responses = in_parallel(
            [lambda: client.post(ONBOARDING, headers=user.headers, json=onboarding_body())] * 4
        )

        outcome = statuses(responses)
        assert outcome[201] >= 1
        assert set(outcome) <= {201, 409}
        assert error_codes(responses, 409) <= {"onboarding_in_progress"}
        assert count(db, VendorProfile) == 1
        assert count(db, Listing) == outcome[201]

    def test_one_vendor_approved_at_once_is_reviewed_once(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        admin: AuthenticatedUser,
    ) -> None:
        submitted = client.post(ONBOARDING, headers=user.headers, json=onboarding_body())
        assert submitted.status_code == 201
        url = f"{ADMIN_VENDORS}/{submitted.json()['vendor']['id']}/approve"

        responses = in_parallel([lambda: client.post(url, headers=admin.headers)] * 4)

        assert statuses(responses) == {200: 1, 409: 3}
        assert error_codes(responses, 409) == {"already_reviewed"}
