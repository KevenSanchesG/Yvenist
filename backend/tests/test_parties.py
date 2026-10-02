import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select
from sqlalchemy.orm import Session

from app.modules.catalog.models import Listing, ListingStatus
from app.modules.parties import service as parties_service
from app.modules.parties.domain import PartyStatus
from app.modules.parties.models import Party, PartyItem, PartySnapshot
from tests.conftest import AuthenticatedUser, CreateListing

PARTIES = "/api/v1/parties"


def new_id() -> str:
    return str(uuid.uuid4())


def party_body(
    *,
    title: str = "Aniversário da Ana",
    status: str = "planning",
    items: list[dict[str, object]] | None = None,
    version: int | None = None,
    **extra: object,
) -> dict[str, object]:
    body: dict[str, object] = {"title": title, "status": status, "items": items or [], **extra}
    if version is not None:
        body["version"] = version
    return body


def item(listing: Listing, *, quantity: int = 1, item_id: str | None = None) -> dict[str, object]:
    return {"id": item_id or new_id(), "listing_id": str(listing.id), "quantity": quantity}


def as_request_items(party: dict) -> list[dict[str, object]]:
    """Reenvia os itens que o servidor devolveu, como o app faz."""
    return [
        {"id": i["id"], "listing_id": i["listing_id"], "quantity": i["quantity"]}
        for i in party["items"]
    ]


def error_code(response) -> str:
    return response.json()["error"]["code"]


@pytest.fixture
def party_with_dj(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
) -> dict:
    """Festa em planejamento, com um DJ, já gravada no servidor."""
    dj = create_listing(title="DJ Festa Boa", category="dj", price_from_cents=80_000)
    response = client.put(
        f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(items=[item(dj)])
    )
    assert response.status_code == 201, response.text
    return response.json()


class TestAccess:
    def test_requires_authentication(self, client: TestClient) -> None:
        party_id = new_id()

        assert client.get(PARTIES).status_code == 401
        assert client.get(f"{PARTIES}/{party_id}").status_code == 401
        assert client.put(f"{PARTIES}/{party_id}", json=party_body()).status_code == 401
        assert client.delete(f"{PARTIES}/{party_id}").status_code == 401

    def test_another_user_cannot_read_change_or_delete_a_party(
        self,
        client: TestClient,
        other_user: AuthenticatedUser,
        party_with_dj: dict,
        db: Session,
    ) -> None:
        url = f"{PARTIES}/{party_with_dj['id']}"

        read = client.get(url, headers=other_user.headers)
        delete = client.delete(url, headers=other_user.headers)
        overwrite = client.put(
            url, headers=other_user.headers, json=party_body(title="Sequestrada")
        )

        # Para quem não é o dono, a festa simplesmente não existe.
        assert read.status_code == delete.status_code == 404
        assert error_code(read) == "party_not_found"
        # O id já está em uso: criar "por cima" é recusado sem alterar nada.
        assert overwrite.status_code == 409
        stored = db.get_one(Party, uuid.UUID(party_with_dj["id"]))
        assert stored.title == "Aniversário da Ana"
        assert client.get(PARTIES, headers=other_user.headers).json() == {"items": []}


class TestCreate:
    def test_creates_an_empty_party(self, client: TestClient, user: AuthenticatedUser) -> None:
        party_id = new_id()

        response = client.put(
            f"{PARTIES}/{party_id}",
            headers=user.headers,
            json=party_body(title="  15 anos   da Maria "),
        )

        assert response.status_code == 201
        body = response.json()
        assert body["id"] == party_id
        assert body["title"] == "15 anos da Maria"
        assert body["status"] == "planning"
        assert body["version"] == 1
        assert body["items"] == []
        assert body["total_cents"] == 0
        assert body["snapshot"] is None

    def test_item_data_comes_from_the_catalog_not_from_the_client(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(title="Salão Glamour", price_from_cents=150_000)
        forged = {
            **item(venue, quantity=2),
            # Um cliente adulterado tentando pagar menos.
            "unit_price_cents": 1,
            "name": "De graça",
            "category": "other",
        }

        response = client.put(
            f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(items=[forged])
        )

        assert response.status_code == 201
        stored = response.json()["items"][0]
        assert stored["name"] == "Salão Glamour"
        assert stored["category"] == "venue"
        assert stored["unit_price_cents"] == 150_000
        assert stored["image_url"] == "https://example.com/capa.jpg"
        assert response.json()["total_cents"] == 300_000

    @pytest.mark.parametrize(
        "status", [ListingStatus.PENDING_REVIEW, ListingStatus.ARCHIVED, ListingStatus.REJECTED]
    )
    def test_cannot_add_a_listing_that_is_not_published(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        status: ListingStatus,
    ) -> None:
        hidden = create_listing(status=status)

        response = client.put(
            f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(items=[item(hidden)])
        )

        assert response.status_code == 422
        assert error_code(response) == "listing_not_available"

    @pytest.mark.parametrize(
        "body",
        [
            party_body(title="   "),
            party_body(title="x" * 81),
            party_body(status="inexistente"),
            party_body(guest_count=0),
            party_body(event_at="2027-01-01T19:00:00"),  # sem fuso horário
            party_body(items=[{"id": "nao-e-uuid", "quantity": 1}]),
            party_body(items=[{"id": str(uuid.uuid4()), "quantity": 0}]),
            party_body(items=[{"id": str(uuid.uuid4()), "quantity": 1000}]),
        ],
        ids=[
            "título vazio",
            "título longo",
            "status desconhecido",
            "zero convidados",
            "data sem fuso",
            "id de item inválido",
            "quantidade zero",
            "quantidade acima do limite",
        ],
    )
    def test_rejects_invalid_payloads(
        self, client: TestClient, user: AuthenticatedUser, body: dict[str, object]
    ) -> None:
        response = client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=body)

        assert response.status_code == 422
        assert error_code(response) == "validation_error"

    def test_stores_event_date_and_guests(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(event_at="2027-01-01T19:00:00-03:00", guest_count=80),
        )

        assert response.status_code == 201
        assert response.json()["event_at"] == "2027-01-01T22:00:00Z"
        assert response.json()["guest_count"] == 80

    def test_enforces_a_limit_of_parties_per_user(
        self, client: TestClient, user: AuthenticatedUser, monkeypatch
    ) -> None:
        monkeypatch.setattr(parties_service, "MAX_PARTIES_PER_USER", 1)
        client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body())

        response = client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body())

        assert response.status_code == 409
        assert error_code(response) == "party_limit_reached"


class TestUpdate:
    def test_updates_content_and_bumps_the_version(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        party_with_dj: dict,
        create_listing: CreateListing,
    ) -> None:
        venue = create_listing(title="Salão Glamour", price_from_cents=150_000)
        items = [*as_request_items(party_with_dj), item(venue)]

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(title="Festa nova", items=items, version=party_with_dj["version"]),
        )

        assert response.status_code == 200
        body = response.json()
        assert body["title"] == "Festa nova"
        assert body["version"] == party_with_dj["version"] + 1
        assert [i["name"] for i in body["items"]] == ["DJ Festa Boa", "Salão Glamour"]
        assert body["total_cents"] == 230_000

    def test_existing_item_keeps_its_price_when_the_listing_changes(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        party_with_dj: dict,
        db: Session,
    ) -> None:
        listing = db.get_one(Listing, uuid.UUID(party_with_dj["items"][0]["listing_id"]))
        listing.price_from_cents = 999_999
        db.commit()
        items = as_request_items(party_with_dj)
        items[0]["quantity"] = 2

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}", headers=user.headers, json=party_body(items=items)
        )

        assert response.json()["items"][0]["unit_price_cents"] == 80_000
        assert response.json()["total_cents"] == 160_000

    def test_removes_items_left_out(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}", headers=user.headers, json=party_body(items=[])
        )

        assert response.json()["items"] == []
        assert db.scalar(select(func.count()).select_from(PartyItem)) == 0

    def test_only_one_venue_per_party(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        first, second = create_listing(), create_listing()

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(first), item(second)]),
        )

        assert response.status_code == 409
        assert error_code(response) == "venue_already_selected"

    def test_venue_can_be_swapped_in_a_single_request(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        first = create_listing(title="Primeiro salão")
        second = create_listing(title="Segundo salão")
        party_id = new_id()
        client.put(
            f"{PARTIES}/{party_id}", headers=user.headers, json=party_body(items=[item(first)])
        )

        response = client.put(
            f"{PARTIES}/{party_id}", headers=user.headers, json=party_body(items=[item(second)])
        )

        assert response.status_code == 200
        assert [i["name"] for i in response.json()["items"]] == ["Segundo salão"]

    def test_stale_version_is_rejected(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        url = f"{PARTIES}/{party_with_dj['id']}"
        items = as_request_items(party_with_dj)
        client.put(
            url,
            headers=user.headers,
            json=party_body(title="Editada no celular", items=items, version=1),
        )

        # O tablet ainda acha que a festa está na versão 1.
        response = client.put(
            url,
            headers=user.headers,
            json=party_body(title="Editada no tablet", items=items, version=1),
        )

        assert response.status_code == 409
        assert error_code(response) == "party_version_conflict"
        assert client.get(url, headers=user.headers).json()["title"] == "Editada no celular"

    def test_repeating_the_same_request_is_safe(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        url = f"{PARTIES}/{party_with_dj['id']}"
        body = party_body(title="Editada", items=as_request_items(party_with_dj), version=1)

        first = client.put(url, headers=user.headers, json=body)
        # A resposta se perdeu e o app repete a mesma requisição.
        retry = client.put(url, headers=user.headers, json=body)

        assert first.status_code == retry.status_code == 200
        assert retry.json()["version"] == first.json()["version"] == 2

    def test_updating_a_deleted_party_is_not_found(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        url = f"{PARTIES}/{party_with_dj['id']}"
        client.delete(url, headers=user.headers)

        response = client.put(
            url, headers=user.headers, json=party_body(title="Fantasma", version=1)
        )

        assert response.status_code == 404
        assert error_code(response) == "party_not_found"

    def test_item_id_already_used_elsewhere_is_a_conflict(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        party_with_dj: dict,
        create_listing: CreateListing,
    ) -> None:
        other_listing = create_listing(category="buffet")
        taken_id = party_with_dj["items"][0]["id"]

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(other_listing, item_id=taken_id)]),
        )

        assert response.status_code == 409
        assert error_code(response) == "party_id_conflict"


class TestLifecycle:
    def lock(self, client: TestClient, user: AuthenticatedUser, party: dict):
        return client.put(
            f"{PARTIES}/{party['id']}",
            headers=user.headers,
            json=party_body(status="locked", items=as_request_items(party)),
        )

    def test_locking_generates_the_quote_snapshot(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        response = self.lock(client, user, party_with_dj)

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "locked"
        assert body["snapshot"]["total_cents"] == 80_000
        assert body["snapshot"]["currency"] == "BRL"
        assert body["snapshot"]["breakdown"] == [
            {
                "listing_id": party_with_dj["items"][0]["listing_id"],
                "category": "dj",
                "name": "DJ Festa Boa",
                "unit_price_cents": 80_000,
                "quantity": 1,
                "subtotal_cents": 80_000,
            }
        ]

    def test_cannot_lock_an_empty_party(self, client: TestClient, user: AuthenticatedUser) -> None:
        party_id = new_id()
        client.put(f"{PARTIES}/{party_id}", headers=user.headers, json=party_body())

        response = client.put(
            f"{PARTIES}/{party_id}", headers=user.headers, json=party_body(status="locked")
        )

        assert response.status_code == 409
        assert error_code(response) == "cannot_lock_without_items"

    def test_locked_party_rejects_changes(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        self.lock(client, user, party_with_dj)

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(status="locked", items=[]),
        )

        assert response.status_code == 409
        assert error_code(response) == "party_locked_mutation_not_allowed"

    def test_unlocking_discards_the_snapshot(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        self.lock(client, user, party_with_dj)

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(status="planning", items=as_request_items(party_with_dj)),
        )

        assert response.status_code == 200
        assert response.json()["status"] == "planning"
        assert response.json()["snapshot"] is None
        assert db.scalar(select(func.count()).select_from(PartySnapshot)) == 0

    def test_can_lock_again_after_unlocking(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        self.lock(client, user, party_with_dj)
        client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(status="planning", items=as_request_items(party_with_dj)),
        )

        assert self.lock(client, user, party_with_dj).json()["snapshot"] is not None

    def test_cancelling_a_locked_party_discards_the_snapshot(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        self.lock(client, user, party_with_dj)

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(status="cancelled", items=as_request_items(party_with_dj)),
        )

        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"
        assert response.json()["snapshot"] is None

    def test_the_client_cannot_mark_a_party_as_paid(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        self.lock(client, user, party_with_dj)

        response = client.put(
            f"{PARTIES}/{party_with_dj['id']}",
            headers=user.headers,
            json=party_body(status="paid", items=as_request_items(party_with_dj)),
        )

        assert response.status_code == 409
        assert error_code(response) == "invalid_party_transition"


class TestReadAndDelete:
    def test_lists_only_own_parties_most_recent_first(
        self, client: TestClient, user: AuthenticatedUser, other_user: AuthenticatedUser
    ) -> None:
        first, second = new_id(), new_id()
        client.put(f"{PARTIES}/{first}", headers=user.headers, json=party_body(title="Primeira"))
        client.put(f"{PARTIES}/{second}", headers=user.headers, json=party_body(title="Segunda"))
        client.put(
            f"{PARTIES}/{new_id()}", headers=other_user.headers, json=party_body(title="Alheia")
        )

        response = client.get(PARTIES, headers=user.headers)

        assert [party["title"] for party in response.json()["items"]] == ["Segunda", "Primeira"]

    def test_listing_parties_does_not_query_per_party(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        db: Session,
    ) -> None:
        dj = create_listing(category="dj")
        for _ in range(5):
            client.put(
                f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(items=[item(dj)])
            )
        statements: list[str] = []

        def record(_conn, _cursor, statement, *_args) -> None:
            statements.append(statement)

        engine = db.get_bind()
        event.listen(engine, "before_cursor_execute", record)
        try:
            response = client.get(PARTIES, headers=user.headers)
        finally:
            event.remove(engine, "before_cursor_execute", record)

        assert len(response.json()["items"]) == 5
        selects = [s for s in statements if s.lstrip().upper().startswith("SELECT")]
        # usuário + festas + itens + snapshots, qualquer que seja o número de festas.
        assert len(selects) == 4

    def test_deletes_the_party_and_its_items(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        response = client.delete(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers)

        assert response.status_code == 204
        assert (
            client.get(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers).status_code == 404
        )
        assert db.scalar(select(func.count()).select_from(PartyItem)) == 0

    def test_paid_party_cannot_be_deleted(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        # Só o servidor marca uma festa como paga; aqui simulamos esse fluxo.
        stored = db.get_one(Party, uuid.UUID(party_with_dj["id"]))
        stored.status = PartyStatus.PAID
        db.commit()

        response = client.delete(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers)

        assert response.status_code == 409
        assert error_code(response) == "paid_party_cannot_be_deleted"

    def test_item_survives_when_its_listing_is_deleted(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        db.delete(db.get_one(Listing, uuid.UUID(party_with_dj["items"][0]["listing_id"])))
        db.commit()

        response = client.get(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers)

        stored = response.json()["items"][0]
        assert stored["listing_id"] is None
        assert stored["name"] == "DJ Festa Boa"
        assert stored["unit_price_cents"] == 80_000


def test_database_enforces_one_venue_per_party(
    db: Session, user: AuthenticatedUser, create_listing: CreateListing
) -> None:
    """A regra do salão único também existe no banco, não só no código."""
    from sqlalchemy.exc import IntegrityError

    from app.core.database import utcnow

    first, second = create_listing(), create_listing()
    party = Party(
        id=uuid.uuid4(),
        owner_id=user.id,
        title="Festa",
        status=PartyStatus.PLANNING,
        created_at=utcnow(),
        updated_at=utcnow(),
        items=[],
        snapshot=None,
    )
    db.add(party)
    db.flush()
    for position, listing in enumerate((first, second)):
        db.add(
            PartyItem(
                id=uuid.uuid4(),
                party_id=party.id,
                listing_id=listing.id,
                category="venue",
                name=listing.title,
                unit_price_cents=listing.price_from_cents,
                currency="BRL",
                quantity=1,
                position=position,
            )
        )

    with pytest.raises(IntegrityError):
        db.flush()
