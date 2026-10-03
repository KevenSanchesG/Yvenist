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
    approved_vendor,
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
QUOTE_REQUESTS = "/api/v1/vendors/me/quote-requests"
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
        chairs = create_listing(category="other", title="Cadeiras")
        body = {
            "title": "Casamento",
            "status": "planning",
            "items": [{"id": str(uuid.uuid4()), "listing_id": str(chairs.id), "quantity": 1}],
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
        first_item = {
            "id": str(uuid.uuid4()),
            "listing_id": str(create_listing(category="other", title="Cadeiras").id),
            "quantity": 1,
        }
        extras = [
            str(create_listing(category="other", title=f"Lembrancinha {index}").id)
            for index in range(PARALLEL)
        ]
        created = client.put(
            url,
            headers=user.headers,
            json={"title": "Casamento", "status": "planning", "items": [first_item]},
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
                    first_item,
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


class TestQuotes:
    """A festa é uma só: o cliente e cada fornecedor gravam nela, um de cada vez."""

    VENDORS = 6

    @pytest.fixture
    def requested(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        register_user: RegisterUser,
        create_listing: CreateListing,
        db: Session,
    ) -> tuple[dict[str, Any], list[AuthenticatedUser]]:
        """Festa com o orçamento solicitado, com um item de cada fornecedor."""
        vendors = []
        items = []
        for index in range(self.VENDORS):
            account = register_user(email=f"fornecedor{index}@example.com")
            # Direto no banco: o documento só precisa ser único.
            profile = approved_vendor(db, account, document=f"{index:011d}")
            listing = create_listing(category="other", title=f"Serviço {index}", vendor=profile)
            vendors.append(account)
            items.append({"id": str(uuid.uuid4()), "listing_id": str(listing.id), "quantity": 1})

        url = f"{PARTIES}/{uuid.uuid4()}"
        body = {
            "title": "Casamento",
            "status": "planning",
            "event_at": "2099-01-01T19:00:00Z",
            "guest_count": 80,
            "items": items,
        }
        assert client.put(url, headers=user.headers, json=body).status_code == 201
        locked = client.put(url, headers=user.headers, json={**body, "status": "locked"})
        assert locked.status_code == 200, locked.text
        return locked.json(), vendors

    def test_every_vendor_answering_at_once_is_recorded(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        requested: tuple[dict[str, Any], list[AuthenticatedUser]],
    ) -> None:
        party, vendors = requested

        def quote(vendor: AuthenticatedUser, item: dict[str, Any]) -> Call:
            url = f"{QUOTE_REQUESTS}/{item['id']}/quote"
            return lambda: client.post(url, headers=vendor.headers, json={"amount_cents": 10_000})

        responses = in_parallel(
            [quote(vendor, item) for vendor, item in zip(vendors, party["items"], strict=True)]
        )

        # Cada resposta trava a festa: sem isso, duas gravariam sobre a mesma
        # versão, e uma delas se perderia ou viraria um erro 500.
        assert statuses(responses) == {200: self.VENDORS}
        stored = client.get(f"{PARTIES}/{party['id']}", headers=user.headers).json()
        assert stored["status"] == "quoted"
        assert {item["quote"]["status"] for item in stored["items"]} == {"quoted"}
        assert stored["quoted_cents"] == self.VENDORS * 10_000
        assert stored["version"] == party["version"] + self.VENDORS
        answers = [entry for entry in stored["history"] if entry["kind"] == "vendor_quoted"]
        assert len(answers) == self.VENDORS

    def test_an_answer_and_a_reopening_at_once_never_mix(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        requested: tuple[dict[str, Any], list[AuthenticatedUser]],
    ) -> None:
        party, vendors = requested
        url = f"{PARTIES}/{party['id']}"
        item = party["items"][0]
        reopen = {
            "title": party["title"],
            "status": "planning",
            "event_at": party["event_at"],
            "guest_count": party["guest_count"],
            "version": party["version"],
            "items": [
                {"id": i["id"], "listing_id": i["listing_id"], "quantity": i["quantity"]}
                for i in party["items"]
            ],
        }

        answer, reopening = in_parallel(
            [
                lambda: client.post(
                    f"{QUOTE_REQUESTS}/{item['id']}/quote",
                    headers=vendors[0].headers,
                    json={"amount_cents": 10_000},
                ),
                lambda: client.put(url, headers=user.headers, json=reopen),
            ]
        )

        # Quem chega depois encontra a festa já mudada: o fornecedor, um pedido
        # que foi retirado; o cliente, uma versão que não é mais a dele.
        assert statuses([answer, reopening]) == {200: 1, 409: 1}
        stored = client.get(url, headers=user.headers).json()
        quote = stored["items"][0]["quote"]["status"]
        if answer.status_code == 200:
            assert error_codes([reopening], 409) == {"party_version_conflict"}
            assert (stored["status"], quote) == ("locked", "quoted")
        else:
            assert error_codes([answer], 409) == {"quote_request_closed"}
            assert (stored["status"], quote) == ("planning", "none")


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
