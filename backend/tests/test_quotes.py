"""Pedidos de orçamento, do lado do fornecedor, e o que eles fazem com a festa."""

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.modules.catalog.pricing import PricingModel
from app.modules.parties.models import Party
from app.modules.vendors.models import VendorProfile
from tests.conftest import AuthenticatedUser, CreateListing, offer
from tests.test_parties import (
    FOUR_HOURS,
    PARTIES,
    as_request_items,
    error_code,
    item,
    new_id,
    own_service,
    party_body,
    put,
)

INBOX = "/api/v1/vendors/me/quote-requests"


def respond(client: TestClient, vendor: AuthenticatedUser, item_id: str, action: str, **body):
    return client.post(f"{INBOX}/{item_id}/{action}", headers=vendor.headers, json=body)


def inbox(client: TestClient, vendor: AuthenticatedUser) -> list[dict]:
    response = client.get(INBOX, headers=vendor.headers)
    assert response.status_code == 200, response.text
    return response.json()["items"]


def reload(client: TestClient, user: AuthenticatedUser, party: dict) -> dict:
    return client.get(f"{PARTIES}/{party['id']}", headers=user.headers).json()


@pytest.fixture
def requested(
    client: TestClient,
    user: AuthenticatedUser,
    create_listing: CreateListing,
    other_vendor_profile: VendorProfile,
) -> dict:
    """Festa com o orçamento solicitado: um DJ de um fornecedor, cadeiras de outro."""
    dj = create_listing(title="DJ Festa Boa", category="dj", price_from_cents=80_000)
    chairs = create_listing(
        title="Cadeiras",
        category="other",
        pricing_model=PricingModel.PER_UNIT,
        price_from_cents=800,
        vendor=other_vendor_profile,
    )
    created = client.put(
        f"{PARTIES}/{new_id()}",
        headers=user.headers,
        json=party_body(
            title="Aniversário da Ana",
            event_type="debutante",
            items=[
                item(dj, notes="Só música dos anos 80.", **FOUR_HOURS),
                item(chairs, quantity=100),
            ],
        ),
    )
    assert created.status_code == 201, created.text
    locked = put(client, user, created.json(), status="locked")
    assert locked.status_code == 200, locked.text
    return locked.json()


def dj_of(party: dict) -> str:
    return party["items"][0]["id"]


def chairs_of(party: dict) -> str:
    return party["items"][1]["id"]


class TestInbox:
    def test_requires_authentication_and_a_vendor_profile(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        assert client.get(INBOX).status_code == 401
        assert client.post(f"{INBOX}/{new_id()}/quote", json={"amount_cents": 1}).status_code == 401

        # Uma conta sem cadastro de fornecedor não tem caixa de pedidos.
        response = client.get(INBOX, headers=user.headers)
        assert response.status_code == 404
        assert error_code(response) == "vendor_profile_not_found"

    def test_a_vendor_sees_only_the_items_of_its_own_listings(
        self,
        client: TestClient,
        vendor_account: AuthenticatedUser,
        other_vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        mine = inbox(client, vendor_account)
        theirs = inbox(client, other_vendor_account)

        assert [request["name"] for request in mine] == ["DJ Festa Boa"]
        assert [request["name"] for request in theirs] == ["Cadeiras"]

    def test_the_request_has_what_is_needed_to_quote_and_nothing_about_the_client(
        self, client: TestClient, vendor_account: AuthenticatedUser, requested: dict
    ) -> None:
        (request,) = inbox(client, vendor_account)

        assert request["item_id"] == dj_of(requested)
        assert request["party_id"] == requested["id"]
        assert request["party_status"] == "locked"
        assert request["quote_round"] == 1
        assert request["event_type"] == "debutante"
        assert request["event_at"] == requested["event_at"]
        assert request["guest_count"] == 80
        assert request["category"] == "dj"
        assert request["pricing_model"] == "fixed"
        assert request["unit_price_cents"] == 80_000
        assert request["estimate_cents"] == 80_000
        assert request["configuration"] == {
            "duration_hours": 4,
            "notes": "Só música dos anos 80.",
        }
        assert request["quote"]["status"] == "pending"
        assert request["can_respond"] is True
        # Nem o nome da festa, nem quem pediu.
        assert "title" not in request
        assert "owner_id" not in request
        assert "Aniversário da Ana" not in str(request)

    def test_a_party_still_being_planned_is_not_shown_to_anyone(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        put(client, user, requested, status="planning")

        # O cliente voltou a editar: o fornecedor não acompanha o que ele muda.
        assert inbox(client, vendor_account) == []

    def test_an_own_service_goes_to_the_owner_of_the_listing_with_what_it_belongs_to(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        create_listing: CreateListing,
    ) -> None:
        venue = create_listing(
            title="Salão Glamour",
            capacity=120,
            offers=(offer("Taxa de limpeza", category="other", price_cents=15_000, required=True),),
        )
        venue_item = item(venue, **FOUR_HOURS)
        created = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(
                items=[venue_item, own_service(venue.offers[0], parent=venue_item["id"])]
            ),
        ).json()
        put(client, user, created, status="locked")

        requests = inbox(client, vendor_account)

        assert [(r["name"], r["relation"], r["parent_name"]) for r in requests] == [
            ("Salão Glamour", "independent", None),
            ("Taxa de limpeza", "required", "Salão Glamour"),
        ]


class TestResponding:
    def test_a_quote_reaches_the_party_of_the_client(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        response = respond(
            client,
            vendor_account,
            dj_of(requested),
            "quote",
            amount_cents=95_000,
            message="  Inclui o equipamento de som. ",
        )

        assert response.status_code == 200, response.text
        assert response.json()["quote"]["status"] == "quoted"
        assert response.json()["quote"]["amount_cents"] == 95_000

        party = reload(client, user, requested)
        quote = party["items"][0]["quote"]
        assert (quote["status"], quote["amount_cents"]) == ("quoted", 95_000)
        assert quote["message"] == "Inclui o equipamento de som."
        assert quote["responded_at"] is not None
        # A estimativa do item continua lá, ao lado do orçamento: são duas coisas.
        assert party["items"][0]["estimate_cents"] == 80_000
        assert party["quoted_cents"] == 95_000
        # Falta o outro fornecedor: a festa continua esperando.
        assert party["status"] == "locked"
        assert party["version"] == requested["version"] + 1
        last = party["history"][-1]
        assert (last["kind"], last["actor"]) == ("vendor_quoted", "vendor")
        assert (last["item_name"], last["amount_cents"]) == ("DJ Festa Boa", 95_000)

    def test_the_party_is_quoted_when_every_vendor_answered(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        other_vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        respond(client, vendor_account, dj_of(requested), "quote", amount_cents=95_000)
        respond(client, other_vendor_account, chairs_of(requested), "quote", amount_cents=70_000)

        party = reload(client, user, requested)

        assert party["status"] == "quoted"
        assert party["quoted_cents"] == 165_000
        assert party["estimate_cents"] == 160_000

    @pytest.mark.parametrize(
        ("action", "status", "kind"),
        [
            ("request-changes", "changes_requested", "vendor_requested_changes"),
            ("decline", "declined", "vendor_declined"),
        ],
    )
    def test_a_change_request_or_a_refusal_asks_the_client_to_edit(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
        action: str,
        status: str,
        kind: str,
    ) -> None:
        response = respond(
            client, vendor_account, dj_of(requested), action, message="Nesse dia só até as 22h."
        )

        assert response.status_code == 200, response.text
        party = reload(client, user, requested)
        assert party["status"] == "edit_requested"
        assert party["items"][0]["quote"]["status"] == status
        assert party["items"][0]["quote"]["message"] == "Nesse dia só até as 22h."
        assert party["history"][-1]["kind"] == kind
        assert party["history"][-1]["message"] == "Nesse dia só até as 22h."

    def test_the_client_edits_and_resends_and_the_history_keeps_everything(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        other_vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        respond(client, other_vendor_account, chairs_of(requested), "quote", amount_cents=70_000)
        respond(
            client, vendor_account, dj_of(requested), "request-changes", message="Só até as 22h."
        )
        asked = reload(client, user, requested)

        editing = put(client, user, asked, status="planning").json()
        # O pedido do fornecedor continua à vista enquanto a pessoa edita.
        assert editing["items"][0]["quote"]["message"] == "Só até as 22h."
        items = as_request_items(editing)
        items[0]["configuration"] = {"duration_hours": 3}
        edited = put(client, user, editing, items=items).json()
        resent = put(client, user, edited, status="locked").json()

        assert resent["status"] == "locked"
        assert resent["quote_round"] == 2
        # O DJ recebe o pedido de novo; quem já tinha dado o preço das cadeiras,
        # que não mudaram, não precisa responder outra vez.
        assert resent["items"][0]["quote"]["status"] == "pending"
        assert resent["items"][1]["quote"]["status"] == "quoted"
        assert [(e["kind"], e["quote_round"]) for e in resent["history"]] == [
            ("quote_requested", 1),
            ("vendor_quoted", 1),
            ("vendor_requested_changes", 1),
            ("reopened", 1),
            ("quote_requested", 2),
        ]
        (again,) = inbox(client, vendor_account)
        assert (again["quote_round"], again["quote"]["status"]) == (2, "pending")
        assert again["configuration"]["duration_hours"] == 3

    def test_the_client_accepts_and_the_vendor_can_no_longer_change_the_answer(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        other_vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        respond(client, vendor_account, dj_of(requested), "quote", amount_cents=95_000)
        respond(client, other_vendor_account, chairs_of(requested), "quote", amount_cents=70_000)
        quoted = reload(client, user, requested)

        confirmed = put(client, user, quoted, status="confirmed")

        assert confirmed.status_code == 200, confirmed.text
        assert confirmed.json()["status"] == "confirmed"
        last = confirmed.json()["history"][-1]
        assert (last["kind"], last["amount_cents"]) == ("confirmed", 165_000)
        (request,) = inbox(client, vendor_account)
        assert (request["party_status"], request["can_respond"]) == ("confirmed", False)

        late = respond(client, vendor_account, dj_of(requested), "quote", amount_cents=1)
        assert late.status_code == 409
        assert error_code(late) == "quote_request_closed"

    def test_cannot_accept_before_every_vendor_answers(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        respond(client, vendor_account, dj_of(requested), "quote", amount_cents=95_000)

        response = put(client, user, reload(client, user, requested), status="confirmed")

        assert response.status_code == 409
        assert error_code(response) == "invalid_party_transition"

    def test_a_cancelled_request_stays_in_the_inbox_as_closed(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        put(client, user, requested, status="cancelled")

        (request,) = inbox(client, vendor_account)

        assert (request["party_status"], request["can_respond"]) == ("cancelled", False)
        late = respond(client, vendor_account, dj_of(requested), "quote", amount_cents=1)
        assert error_code(late) == "quote_request_closed"

    def test_a_vendor_cannot_answer_for_another_vendor(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        response = respond(client, vendor_account, chairs_of(requested), "quote", amount_cents=1)

        # O item de outro anunciante simplesmente não existe para quem pergunta.
        assert response.status_code == 404
        assert error_code(response) == "quote_request_not_found"
        assert reload(client, user, requested)["items"][1]["quote"]["status"] == "pending"

    def test_the_client_cannot_answer_its_own_request(
        self, client: TestClient, user: AuthenticatedUser, requested: dict
    ) -> None:
        response = respond(client, user, dj_of(requested), "quote", amount_cents=1)

        assert response.status_code == 404
        assert error_code(response) == "vendor_profile_not_found"

    def test_unknown_request_is_404(
        self, client: TestClient, vendor_account: AuthenticatedUser, requested: dict
    ) -> None:
        response = respond(client, vendor_account, new_id(), "quote", amount_cents=1)

        assert response.status_code == 404
        assert error_code(response) == "quote_request_not_found"

    @pytest.mark.parametrize(
        ("action", "body"),
        [
            ("quote", {}),
            ("quote", {"amount_cents": -1}),
            ("quote", {"amount_cents": 1_000_000_001}),
            ("quote", {"amount_cents": 100, "message": "x" * 501}),
            ("request-changes", {}),
            ("request-changes", {"message": "  ok "}),
            ("decline", {"message": ""}),
        ],
        ids=[
            "orçamento sem valor",
            "valor negativo",
            "valor acima do teto",
            "mensagem longa demais",
            "pedido de alteração sem motivo",
            "motivo curto demais",
            "recusa sem motivo",
        ],
    )
    def test_rejects_an_invalid_answer(
        self,
        client: TestClient,
        vendor_account: AuthenticatedUser,
        requested: dict,
        action: str,
        body: dict[str, object],
    ) -> None:
        response = respond(client, vendor_account, dj_of(requested), action, **body)

        assert response.status_code == 422
        assert error_code(response) == "validation_error"


class TestStaleClient:
    def test_a_client_holding_an_old_copy_is_told_to_reload(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        other_vendor_account: AuthenticatedUser,
        requested: dict,
    ) -> None:
        # O app ainda acha que a festa está "solicitada", na versão que ele leu.
        respond(client, vendor_account, dj_of(requested), "quote", amount_cents=95_000)
        respond(client, other_vendor_account, chairs_of(requested), "quote", amount_cents=70_000)

        response = put(client, user, requested, status="locked", version=requested["version"])

        # A regra que falharia ("orçamento recebido" não volta para
        # "solicitado") é consequência da cópia velha: o que o app precisa
        # saber é que tem de recarregar.
        assert response.status_code == 409
        assert error_code(response) == "party_version_conflict"

    def test_the_answer_of_a_vendor_bumps_the_version(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        vendor_account: AuthenticatedUser,
        requested: dict,
        db: Session,
    ) -> None:
        respond(client, vendor_account, dj_of(requested), "quote", amount_cents=95_000)

        stored = db.get_one(Party, uuid.UUID(requested["id"]))
        assert stored.version == requested["version"] + 1
        # Voltar a editar sobre a versão antiga é recusado, sem perder a resposta.
        stale = put(client, user, requested, status="planning", version=requested["version"])
        assert error_code(stale) == "party_version_conflict"
        assert reload(client, user, requested)["items"][0]["quote"]["status"] == "quoted"
