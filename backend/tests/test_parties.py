import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, func, select
from sqlalchemy.orm import Session

from app.modules.catalog.models import Listing, ListingOffer, ListingStatus
from app.modules.catalog.pricing import PricingModel
from app.modules.parties import service as parties_service
from app.modules.parties.domain import PartyStatus
from app.modules.parties.models import Party, PartyEvent, PartyItem, PartySnapshot
from tests.conftest import AuthenticatedUser, CreateListing, offer

PARTIES = "/api/v1/parties"

# Uma data que continua no futuro por muito tempo.
EVENT_AT = (datetime.now(UTC) + timedelta(days=90)).replace(microsecond=0).isoformat()
# A configuração de um item contratado por um tempo (DJ, salão, atração).
FOUR_HOURS: dict[str, Any] = {"duration_hours": 4}


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
    body: dict[str, object] = {
        "title": title,
        "status": status,
        "event_at": EVENT_AT,
        "guest_count": 80,
        "items": items or [],
        **extra,
    }
    if version is not None:
        body["version"] = version
    return body


def item(
    listing: Listing,
    *,
    quantity: int = 1,
    item_id: str | None = None,
    parent: object = None,
    **configuration: object,
) -> dict[str, object]:
    """Um item da festa como o app o envia. [parent] é o id do item a que ele se liga."""
    return {
        "id": item_id or new_id(),
        "listing_id": str(listing.id),
        "parent_item_id": parent,
        "quantity": quantity,
        "configuration": configuration,
    }


def own_service(service: ListingOffer, *, parent: object, **configuration: object) -> dict:
    return {
        "id": new_id(),
        "offer_id": str(service.id),
        "parent_item_id": parent,
        "quantity": 1,
        "configuration": configuration,
    }


def as_request_items(party: dict) -> list[dict[str, object]]:
    """Reenvia os itens que o servidor devolveu, como o app faz."""
    return [
        {
            "id": i["id"],
            "listing_id": i["listing_id"],
            "offer_id": i["offer_id"],
            "parent_item_id": i["parent_item_id"],
            "quantity": i["quantity"],
            "configuration": i["configuration"],
        }
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
        f"{PARTIES}/{new_id()}",
        headers=user.headers,
        json=party_body(items=[item(dj, **FOUR_HOURS)]),
    )
    assert response.status_code == 201, response.text
    return response.json()


def put(client: TestClient, user: AuthenticatedUser, party: dict, **changes: object):
    """Grava a festa de novo, com o que mudou, sobre a versão que o teste tem."""
    body = party_body(
        title=party["title"],
        status=party["status"],
        items=as_request_items(party),
        event_at=party["event_at"],
        guest_count=party["guest_count"],
        event_type=party["event_type"],
    )
    body.update(changes)
    return client.put(f"{PARTIES}/{party['id']}", headers=user.headers, json=body)


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
    def test_creates_an_event_without_items(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        party_id = new_id()

        response = client.put(
            f"{PARTIES}/{party_id}",
            headers=user.headers,
            json=party_body(title="  15 anos   da Maria ", event_type="debutante"),
        )

        assert response.status_code == 201
        body = response.json()
        assert body["id"] == party_id
        # O dono é sempre quem está autenticado, nunca um valor enviado.
        assert body["owner_id"] == str(user.id)
        assert body["title"] == "15 anos da Maria"
        assert body["event_type"] == "debutante"
        assert body["guest_count"] == 80
        assert body["status"] == "planning"
        assert body["version"] == 1
        assert body["quote_round"] == 0
        assert body["items"] == []
        assert body["estimate_cents"] == 0
        assert body["unpriced_items"] == 0
        assert body["quoted_cents"] is None
        assert body["snapshot"] is None
        assert body["history"] == []

    def test_item_data_comes_from_the_catalog_not_from_the_client(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(title="Salão Glamour", price_from_cents=150_000, capacity=200)
        forged = {
            **item(venue, **FOUR_HOURS),
            # Um cliente adulterado tentando pagar menos e se dar um orçamento.
            "unit_price_cents": 1,
            "pricing_model": "per_unit",
            "name": "De graça",
            "category": "other",
            "relation": "required",
            "vendor_id": new_id(),
            "capacity": 100_000,
            "estimate_cents": 1,
            "quote": {"status": "quoted", "amount_cents": 1},
        }

        response = client.put(
            f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(items=[forged])
        )

        assert response.status_code == 201
        stored = response.json()["items"][0]
        assert stored["name"] == "Salão Glamour"
        assert stored["category"] == "venue"
        assert stored["pricing_model"] == "fixed"
        assert stored["unit_price_cents"] == 150_000
        assert stored["capacity"] == 200
        assert stored["relation"] == "independent"
        assert stored["vendor_id"] == str(venue.vendor_id)
        assert stored["image_url"] == "https://example.com/capa.jpg"
        assert stored["estimate_cents"] == 150_000
        assert stored["quote"] == {
            "status": "none",
            "amount_cents": None,
            "message": None,
            "responded_at": None,
        }
        assert response.json()["estimate_cents"] == 150_000

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
        hidden = create_listing(category="dj", status=status)

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(hidden, **FOUR_HOURS)]),
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
            party_body(event_type="x" * 41),
            party_body(items=[{"id": "nao-e-uuid", "quantity": 1}]),
            party_body(items=[{"id": str(uuid.uuid4()), "quantity": 0}]),
            party_body(items=[{"id": str(uuid.uuid4()), "quantity": 1000}]),
            party_body(items=[{"id": str(uuid.uuid4()), "configuration": {"notes": 1.5}}]),
            party_body(items=[{"id": str(uuid.uuid4()), "configuration": {"notes": "x" * 1001}}]),
            party_body(items=[{"id": str(uuid.uuid4()), "configuration": {"notes": ["a"]}}]),
        ],
        ids=[
            "título vazio",
            "título longo",
            "status desconhecido",
            "zero convidados",
            "data sem fuso",
            "tipo de evento longo",
            "id de item inválido",
            "quantidade zero",
            "quantidade acima do limite",
            "configuração com número quebrado",
            "configuração com texto desproporcional",
            "configuração com lista",
        ],
    )
    def test_rejects_invalid_payloads(
        self, client: TestClient, user: AuthenticatedUser, body: dict[str, object]
    ) -> None:
        response = client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=body)

        assert response.status_code == 422
        assert error_code(response) == "validation_error"

    def test_stores_event_date_in_utc(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(event_at="2099-01-01T19:00:00-03:00", guest_count=80),
        )

        assert response.status_code == 201
        assert response.json()["event_at"] == "2099-01-01T22:00:00Z"

    @pytest.mark.parametrize(
        ("change", "code"),
        [
            ({"event_at": "2020-01-01T19:00:00Z"}, "event_date_in_past"),
            ({"event_type": "inexistente"}, "unknown_event_type"),
        ],
    )
    def test_rejects_an_event_that_cannot_be(
        self, client: TestClient, user: AuthenticatedUser, change: dict[str, Any], code: str
    ) -> None:
        response = client.put(
            f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body(**change)
        )

        assert response.status_code == 422
        assert error_code(response) == code

    def test_enforces_a_limit_of_parties_per_user(
        self, client: TestClient, user: AuthenticatedUser, monkeypatch
    ) -> None:
        monkeypatch.setattr(parties_service, "MAX_PARTIES_PER_USER", 1)
        client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body())

        response = client.put(f"{PARTIES}/{new_id()}", headers=user.headers, json=party_body())

        assert response.status_code == 409
        assert error_code(response) == "party_limit_reached"


class TestComposition:
    def test_each_item_is_estimated_by_how_it_charges(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        dj = create_listing(category="dj", price_from_cents=80_000)
        buffet = create_listing(
            category="buffet",
            pricing_model=PricingModel.PER_PERSON,
            price_from_cents=6_000,
            minimum_price_cents=250_000,
        )
        band = create_listing(
            category="attraction", pricing_model=PricingModel.PER_HOUR, price_from_cents=20_000
        )
        chairs = create_listing(
            category="other", pricing_model=PricingModel.PER_UNIT, price_from_cents=800
        )
        flowers = create_listing(category="decoration", pricing_model=PricingModel.ON_REQUEST)

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(
                items=[
                    item(dj, **FOUR_HOURS),
                    item(buffet, service_style="plated"),
                    item(band, duration_hours=3),
                    item(chairs, quantity=100),
                    item(flowers, theme="Safari"),
                ]
            ),
        )

        assert response.status_code == 201, response.text
        body = response.json()
        assert [i["estimate_cents"] for i in body["items"]] == [
            80_000,  # fixo
            480_000,  # 80 convidados x R$ 60
            60_000,  # 3 horas x R$ 200
            80_000,  # 100 unidades x R$ 8
            None,  # sob consulta
        ]
        assert body["estimate_cents"] == 700_000
        # O item sob consulta fica fora da soma, e a resposta diz que ficou.
        assert body["unpriced_items"] == 1
        assert body["items"][4]["pricing_model"] == "on_request"
        assert body["items"][4]["unit_price_cents"] is None
        assert body["items"][1]["minimum_cents"] == 250_000

    def test_the_configuration_is_validated_by_the_category(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        decoration = create_listing(category="decoration")

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(decoration, environment="na lua", duration_hours=4)]),
        )

        assert response.status_code == 422
        assert error_code(response) == "invalid_item_configuration"
        assert response.json()["error"]["details"] == {
            "fields": [
                {"field": "duration_hours", "message": "Este item não tem esta informação."},
                {"field": "theme", "message": "Campo obrigatório."},
                {"field": "environment", "message": "Opção inválida."},
            ]
        }

    def test_stores_the_clean_configuration(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        decoration = create_listing(category="decoration")

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(decoration, quantity=3, theme="  Safari ", notes="   ")]),
        )

        assert response.status_code == 201, response.text
        stored = response.json()["items"][0]
        assert stored["configuration"] == {"theme": "Safari"}
        assert stored["quantity"] == 3

    def test_a_venue_comes_with_its_own_services(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(
            title="Salão Glamour",
            price_from_cents=150_000,
            capacity=120,
            offers=(
                offer("Buffet da casa", pricing_model=PricingModel.PER_PERSON, price_cents=4_500),
                offer("Taxa de limpeza", category="other", price_cents=15_000, required=True),
            ),
        )
        buffet, cleaning = venue.offers
        venue_item = item(venue, **FOUR_HOURS)

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(
                items=[
                    venue_item,
                    own_service(buffet, parent=venue_item["id"]),
                    own_service(cleaning, parent=venue_item["id"]),
                ]
            ),
        )

        assert response.status_code == 201, response.text
        _, own_buffet, fee = response.json()["items"]
        assert own_buffet["relation"] == "linked"
        assert own_buffet["parent_item_id"] == venue_item["id"]
        assert own_buffet["listing_id"] is None
        assert own_buffet["offer_id"] == str(buffet.id)
        assert own_buffet["vendor_id"] == str(venue.vendor_id)
        assert own_buffet["estimate_cents"] == 80 * 4_500
        assert fee["relation"] == "required"
        assert response.json()["estimate_cents"] == 150_000 + 360_000 + 15_000

    def test_a_venue_does_not_enter_without_what_is_required(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(offers=(offer("Taxa", category="other", required=True),))

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(venue, **FOUR_HOURS)]),
        )

        assert response.status_code == 409
        assert error_code(response) == "required_item_missing"

    def test_removing_the_venue_takes_its_own_services_and_frees_the_partner(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        db: Session,
    ) -> None:
        band = create_listing(
            title="Banda", category="attraction", pricing_model=PricingModel.PER_HOUR
        )
        venue = create_listing(
            title="Salão",
            capacity=120,
            offers=(offer("Taxa", category="other", required=True),),
            partners=(band,),
        )
        venue_item = item(venue, **FOUR_HOURS)
        created = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(
                items=[
                    venue_item,
                    own_service(venue.offers[0], parent=venue_item["id"]),
                    item(band, parent=venue_item["id"], duration_hours=3),
                ]
            ),
        ).json()
        assert [i["relation"] for i in created["items"]] == [
            "independent",
            "required",
            "recommended",
        ]

        # Tirar só o salão deixa para trás um serviço que não existe sem ele.
        orphaned = put(client, user, created, items=as_request_items(created)[1:])
        assert orphaned.status_code == 409
        assert error_code(orphaned) == "parent_item_missing"

        kept = as_request_items(created)[2:]
        response = put(client, user, created, items=kept)

        assert response.status_code == 200, response.text
        (survivor,) = response.json()["items"]
        # A banda é um anúncio à parte: continua na festa, por conta própria.
        assert survivor["name"] == "Banda"
        assert survivor["relation"] == "independent"
        assert survivor["parent_item_id"] is None
        assert db.scalar(select(func.count()).select_from(PartyItem)) == 1

    def test_a_relation_the_catalog_does_not_know_is_rejected(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(capacity=120)
        stranger = create_listing(category="dj")
        venue_item = item(venue, **FOUR_HOURS)

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(
                items=[venue_item, item(stranger, parent=venue_item["id"], **FOUR_HOURS)]
            ),
        )

        assert response.status_code == 422
        assert error_code(response) == "invalid_item_relation"

    def test_the_guests_have_to_fit_in_the_venue(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        venue = create_listing(capacity=60)

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(venue, **FOUR_HOURS)]),
        )

        assert response.status_code == 409
        assert error_code(response) == "guest_count_exceeds_capacity"
        assert "60" in response.json()["error"]["message"]


class TestUpdate:
    def test_updates_content_and_bumps_the_version(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        party_with_dj: dict,
        create_listing: CreateListing,
    ) -> None:
        venue = create_listing(title="Salão Glamour", price_from_cents=150_000)
        items = [*as_request_items(party_with_dj), item(venue, **FOUR_HOURS)]

        response = put(client, user, party_with_dj, title="Festa nova", items=items, version=1)

        assert response.status_code == 200
        body = response.json()
        assert body["title"] == "Festa nova"
        assert body["version"] == party_with_dj["version"] + 1
        assert [i["name"] for i in body["items"]] == ["DJ Festa Boa", "Salão Glamour"]
        assert body["estimate_cents"] == 230_000

    def test_existing_item_keeps_its_price_when_the_listing_changes(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        party_with_dj: dict,
        db: Session,
    ) -> None:
        listing = db.get_one(Listing, uuid.UUID(party_with_dj["items"][0]["listing_id"]))
        listing.price_from_cents = 999_999
        listing.pricing_model = PricingModel.PER_HOUR
        db.commit()
        items = as_request_items(party_with_dj)
        items[0]["configuration"] = {"duration_hours": 6}

        response = put(client, user, party_with_dj, items=items)

        stored = response.json()["items"][0]
        assert stored["unit_price_cents"] == 80_000
        assert stored["pricing_model"] == "fixed"
        assert stored["configuration"] == {"duration_hours": 6}
        assert response.json()["estimate_cents"] == 80_000

    def test_removes_items_left_out_and_keeps_the_event(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        response = put(client, user, party_with_dj, items=[])

        # Um evento sem itens continua existindo: a pessoa segue montando.
        assert response.status_code == 200
        assert response.json()["items"] == []
        assert response.json()["title"] == "Aniversário da Ana"
        assert db.scalar(select(func.count()).select_from(PartyItem)) == 0

    def test_only_one_venue_per_party(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        first, second = create_listing(), create_listing()

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(first, **FOUR_HOURS), item(second, **FOUR_HOURS)]),
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
            f"{PARTIES}/{party_id}",
            headers=user.headers,
            json=party_body(items=[item(first, **FOUR_HOURS)]),
        )

        response = client.put(
            f"{PARTIES}/{party_id}",
            headers=user.headers,
            json=party_body(items=[item(second, **FOUR_HOURS)]),
        )

        assert response.status_code == 200
        assert [i["name"] for i in response.json()["items"]] == ["Segundo salão"]

    def test_stale_version_is_rejected(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        url = f"{PARTIES}/{party_with_dj['id']}"
        put(client, user, party_with_dj, title="Editada no celular", version=1)

        # O tablet ainda acha que a festa está na versão 1.
        response = put(client, user, party_with_dj, title="Editada no tablet", version=1)

        assert response.status_code == 409
        assert error_code(response) == "party_version_conflict"
        assert client.get(url, headers=user.headers).json()["title"] == "Editada no celular"

    def test_repeating_the_same_request_is_safe(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        first = put(client, user, party_with_dj, title="Editada", version=1)
        # A resposta se perdeu e o app repete a mesma requisição.
        retry = put(client, user, party_with_dj, title="Editada", version=1)

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
        other_listing = create_listing(category="other")
        taken_id = party_with_dj["items"][0]["id"]

        response = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(other_listing, item_id=taken_id)]),
        )

        assert response.status_code == 409
        assert error_code(response) == "party_id_conflict"


class TestQuoteRequest:
    def test_requesting_takes_a_picture_of_the_estimate(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        response = put(client, user, party_with_dj, status="locked")

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "locked"
        assert body["quote_round"] == 1
        assert body["items"][0]["quote"]["status"] == "pending"
        assert body["snapshot"]["total_cents"] == 80_000
        assert body["snapshot"]["currency"] == "BRL"
        assert body["snapshot"]["breakdown"] == [
            {
                "listing_id": party_with_dj["items"][0]["listing_id"],
                "offer_id": None,
                "category": "dj",
                "name": "DJ Festa Boa",
                "pricing_model": "fixed",
                "unit_price_cents": 80_000,
                "quantity": 1,
                "subtotal_cents": 80_000,
            }
        ]
        (entry,) = body["history"]
        assert (entry["kind"], entry["actor"]) == ("quote_requested", "client")
        assert (entry["quote_round"], entry["amount_cents"]) == (1, 80_000)

    def test_cannot_request_for_an_empty_party(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        party_id = new_id()
        client.put(f"{PARTIES}/{party_id}", headers=user.headers, json=party_body())

        response = client.put(
            f"{PARTIES}/{party_id}", headers=user.headers, json=party_body(status="locked")
        )

        assert response.status_code == 409
        assert error_code(response) == "cannot_lock_without_items"

    @pytest.mark.parametrize(
        ("missing", "code"),
        [
            ({"event_at": None}, "event_date_required"),
            ({"guest_count": None}, "guest_count_required"),
        ],
        ids=["sem data", "sem convidados"],
    )
    def test_needs_the_date_and_the_guests(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        missing: dict[str, Any],
        code: str,
    ) -> None:
        dj = create_listing(category="dj")
        created = client.put(
            f"{PARTIES}/{new_id()}",
            headers=user.headers,
            json=party_body(items=[item(dj, **FOUR_HOURS)], **missing),
        ).json()

        response = put(client, user, created, status="locked")

        assert response.status_code == 409
        assert error_code(response) == code

    def test_an_item_whose_listing_left_the_catalog_blocks_the_request(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        listing = db.get_one(Listing, uuid.UUID(party_with_dj["items"][0]["listing_id"]))
        listing.status = ListingStatus.ARCHIVED
        db.commit()

        response = put(client, user, party_with_dj, status="locked")

        assert response.status_code == 409
        assert error_code(response) == "item_no_longer_available"
        assert "DJ Festa Boa" in response.json()["error"]["message"]

    def test_requested_party_rejects_changes(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()

        response = put(client, user, locked, items=[])

        assert response.status_code == 409
        assert error_code(response) == "party_locked_mutation_not_allowed"

    def test_reopening_discards_the_picture_and_keeps_the_history(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()

        response = put(client, user, locked, status="planning")

        assert response.status_code == 200
        body = response.json()
        assert body["status"] == "planning"
        assert body["snapshot"] is None
        assert body["items"][0]["quote"]["status"] == "none"
        assert [entry["kind"] for entry in body["history"]] == ["quote_requested", "reopened"]
        assert db.scalar(select(func.count()).select_from(PartySnapshot)) == 0

    def test_requesting_again_is_a_new_round(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()
        editing = put(client, user, locked, status="planning").json()

        body = put(client, user, editing, status="locked").json()

        assert body["snapshot"] is not None
        assert body["quote_round"] == 2
        assert [(e["kind"], e["quote_round"]) for e in body["history"]] == [
            ("quote_requested", 1),
            ("reopened", 1),
            ("quote_requested", 2),
        ]

    def test_cancelling_a_requested_party_discards_the_picture(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()

        response = put(client, user, locked, status="cancelled")

        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"
        assert response.json()["snapshot"] is None
        assert response.json()["history"][-1]["kind"] == "cancelled"

    @pytest.mark.parametrize("target", ["paid", "quoted", "edit_requested", "confirmed"])
    def test_the_client_cannot_set_what_only_the_server_sets(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, target: str
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()

        response = put(client, user, locked, status=target)

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
                f"{PARTIES}/{new_id()}",
                headers=user.headers,
                json=party_body(items=[item(dj, **FOUR_HOURS)]),
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
        # usuário + festas + itens + snapshots + histórico, qualquer que seja o
        # número de festas.
        assert len(selects) == 5

    def test_deletes_the_party_with_its_items_and_history(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict, db: Session
    ) -> None:
        locked = put(client, user, party_with_dj, status="locked").json()
        put(client, user, locked, status="cancelled")

        response = client.delete(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers)

        assert response.status_code == 204
        assert (
            client.get(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers).status_code == 404
        )
        assert db.scalar(select(func.count()).select_from(PartyItem)) == 0
        assert db.scalar(select(func.count()).select_from(PartyEvent)) == 0

    def test_a_party_the_vendors_are_answering_is_cancelled_before_it_is_deleted(
        self, client: TestClient, user: AuthenticatedUser, party_with_dj: dict
    ) -> None:
        put(client, user, party_with_dj, status="locked")

        response = client.delete(f"{PARTIES}/{party_with_dj['id']}", headers=user.headers)

        assert response.status_code == 409
        assert error_code(response) == "party_has_open_quote"

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
        assert stored["estimate_cents"] == 80_000


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
        events=[],
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
                pricing_model=PricingModel.FIXED,
                unit_price_cents=listing.price_from_cents,
                currency="BRL",
                quantity=1,
                position=position,
            )
        )

    with pytest.raises(IntegrityError):
        db.flush()
