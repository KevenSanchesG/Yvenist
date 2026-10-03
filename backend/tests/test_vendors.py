import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.modules.catalog.models import Listing, ListingStatus
from app.modules.vendors.models import VendorProfile, VendorStatus
from tests.conftest import (
    VALID_ALPHANUMERIC_CNPJ,
    VALID_CNPJ,
    VALID_CPFS,
    AuthenticatedUser,
    CreateListing,
)

ONBOARDING = "/api/v1/vendors/onboarding"
MY_VENDOR = "/api/v1/vendors/me"
MY_LISTINGS = "/api/v1/vendors/me/listings"
ADMIN_VENDORS = "/api/v1/admin/vendors"
ADMIN_LISTINGS = "/api/v1/admin/listings"
CATALOG = "/api/v1/catalog/listings"

# CPF usado nos envios deste arquivo (o primeiro da lista é do fornecedor da fixture).
CPF = VALID_CPFS[1]


def vendor_data(**overrides: object) -> dict[str, object]:
    data: dict[str, object] = {
        "person_type": "pf",
        "document": CPF,
        "legal_name": "Maria Oliveira",
    }
    data.update(overrides)
    return data


def listing_data(**overrides: object) -> dict[str, object]:
    data: dict[str, object] = {
        "category": "venue",
        "title": "Espaço Crystal",
        "description": "Salão amplo, climatizado, com cozinha equipada e área kids.",
        "neighborhood": "Campo Grande",
        "city": "Rio de Janeiro",
        "state": "rj",
        "price_from_cents": 250_000,
        "capacity": 150,
        "area_m2": 300,
        "amenities": ["wifi", "kitchen", "wifi"],
        "event_types": ["wedding", "debutante"],
        "cancellation_policy": "moderate",
    }
    data.update(overrides)
    return data


def onboarding(
    client: TestClient,
    user: AuthenticatedUser,
    *,
    vendor: dict[str, object] | None = None,
    listing: dict[str, object] | None = None,
    include_vendor: bool = True,
):
    body: dict[str, object] = {"listing": listing or listing_data()}
    if include_vendor:
        body["vendor"] = vendor or vendor_data()
    return client.post(ONBOARDING, headers=user.headers, json=body)


def error_code(response) -> str:
    return response.json()["error"]["code"]


class TestOnboarding:
    def test_requires_authentication(self, client: TestClient) -> None:
        assert client.post(ONBOARDING, json={"listing": listing_data()}).status_code == 401
        assert client.get(MY_VENDOR).status_code == 401
        assert client.get(MY_LISTINGS).status_code == 401

    def test_user_without_vendor_profile_gets_404(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.get(MY_VENDOR, headers=user.headers)

        assert response.status_code == 404
        assert error_code(response) == "vendor_profile_not_found"

    def test_creates_profile_and_listing_pending_review(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = onboarding(client, user)

        assert response.status_code == 201
        body = response.json()
        assert body["vendor"]["status"] == "pending_review"
        assert body["vendor"]["legal_name"] == "Maria Oliveira"
        assert body["listing"]["status"] == "pending_review"
        assert body["listing"]["title"] == "Espaço Crystal"
        assert body["listing"]["state"] == "RJ"
        # Sem repetição e em ordem estável.
        assert body["listing"]["amenities"] == ["kitchen", "wifi"]
        assert body["listing"]["event_types"] == ["wedding", "debutante"]
        assert body["listing"]["cancellation_policy"] == "moderate"

    def test_never_exposes_the_full_document(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user)
        profile = client.get(MY_VENDOR, headers=user.headers)

        assert created.json()["vendor"]["document_masked"] == f"{CPF[:3]}.***.***-{CPF[9:]}"
        assert CPF not in created.text
        assert CPF not in profile.text

    def test_pending_listing_is_not_in_the_public_catalog(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        listing_id = onboarding(client, user).json()["listing"]["id"]

        assert client.get(CATALOG).json()["items"] == []
        assert client.get(f"{CATALOG}/{listing_id}").status_code == 404
        mine = client.get(MY_LISTINGS, headers=user.headers).json()["items"]
        assert [listing["id"] for listing in mine] == [listing_id]

    @pytest.mark.parametrize(
        ("person_type", "document"),
        [
            ("pf", "529.982.247-25"),
            ("pj", "11.222.333/0001-81"),
            ("pj", VALID_ALPHANUMERIC_CNPJ),
        ],
        ids=["cpf formatado", "cnpj formatado", "cnpj alfanumérico"],
    )
    def test_accepts_valid_documents(
        self, client: TestClient, user: AuthenticatedUser, person_type: str, document: str
    ) -> None:
        response = onboarding(
            client, user, vendor=vendor_data(person_type=person_type, document=document)
        )

        assert response.status_code == 201

    @pytest.mark.parametrize(
        ("person_type", "document"),
        [
            ("pf", "12345678900"),
            ("pf", VALID_CNPJ),
            ("pj", CPF),
            ("pj", "11222333000180"),
            ("pf", ""),
        ],
        ids=["cpf inválido", "cnpj como pf", "cpf como pj", "cnpj inválido", "vazio"],
    )
    def test_rejects_invalid_documents(
        self, client: TestClient, user: AuthenticatedUser, person_type: str, document: str
    ) -> None:
        response = onboarding(
            client, user, vendor=vendor_data(person_type=person_type, document=document)
        )

        assert response.status_code == 422

    def test_first_listing_requires_the_vendor_data(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = onboarding(client, user, include_vendor=False)

        assert response.status_code == 422
        assert error_code(response) == "vendor_data_required"

    def test_document_cannot_be_reused_by_another_account(
        self, client: TestClient, user: AuthenticatedUser, other_user: AuthenticatedUser
    ) -> None:
        onboarding(client, user)

        response = onboarding(client, other_user)

        assert response.status_code == 409
        assert error_code(response) == "document_already_registered"

    def test_second_listing_reuses_the_existing_profile(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        onboarding(client, user)

        response = onboarding(
            client, user, include_vendor=False, listing=listing_data(title="Segundo espaço")
        )

        assert response.status_code == 201
        assert len(client.get(MY_LISTINGS, headers=user.headers).json()["items"]) == 2
        assert len(list(db.scalars(select(VendorProfile)))) == 1

    @pytest.mark.parametrize(
        "overrides",
        [
            {"category": "inexistente"},
            {"event_types": ["wedding", "inexistente"]},
        ],
        ids=["categoria", "tipo de evento"],
    )
    def test_rejects_unknown_reference_data(
        self, client: TestClient, user: AuthenticatedUser, overrides: dict[str, object]
    ) -> None:
        response = onboarding(client, user, listing=listing_data(**overrides))

        assert response.status_code == 422
        assert error_code(response) in {"unknown_category", "unknown_event_type"}

    def test_failed_listing_does_not_leave_a_profile_behind(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        onboarding(client, user, listing=listing_data(category="inexistente"))

        # Cadastro e anúncio são uma transação só: ou entram os dois, ou nenhum.
        assert db.scalar(select(VendorProfile)) is None

    @pytest.mark.parametrize(
        "overrides",
        [
            {"title": "ab"},
            {"description": "curta"},
            {"state": "XX"},
            {"price_from_cents": -1},
            {"price_from_cents": 100_000_001},
            {"capacity": 0},
            {"area_m2": 0},
            {"amenities": ["piscina-olimpica"]},
            {"cancellation_policy": "inexistente"},
            {"cover_image_url": "http://example.com/capa.jpg"},
            {"cover_image_url": "javascript:alert(1)"},
        ],
        ids=[
            "título curto",
            "descrição curta",
            "uf inválida",
            "preço negativo",
            "preço acima do teto",
            "capacidade zero",
            "área zero",
            "comodidade desconhecida",
            "política desconhecida",
            "imagem sem https",
            "imagem com esquema perigoso",
        ],
    )
    def test_rejects_invalid_listing_data(
        self, client: TestClient, user: AuthenticatedUser, overrides: dict[str, object]
    ) -> None:
        response = onboarding(client, user, listing=listing_data(**overrides))

        assert response.status_code == 422
        assert error_code(response) == "validation_error"

    def test_client_cannot_choose_status_or_ratings(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        response = onboarding(
            client,
            user,
            vendor=vendor_data(status="approved"),
            listing=listing_data(status="published", rating_average=5, rating_count=999),
        )

        assert response.status_code == 201
        assert response.json()["vendor"]["status"] == "pending_review"
        stored = db.scalar(select(Listing))
        assert stored is not None
        assert stored.status is ListingStatus.PENDING_REVIEW
        assert stored.rating_count == 0
        assert stored.published_at is None

    def test_listing_becomes_searchable_text(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        onboarding(client, user)

        stored = db.scalar(select(Listing))
        assert stored is not None
        assert stored.search_text == "espaco crystal campo grande rio de janeiro rj saloes"


class TestPricingAndOwnServices:
    def test_a_listing_is_fixed_price_unless_it_says_otherwise(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        listing = onboarding(client, user).json()["listing"]

        assert listing["pricing_model"] == "fixed"
        assert listing["price_from_cents"] == 250_000
        assert listing["minimum_price_cents"] is None
        assert listing["offers"] == []
        assert listing["partners"] == []

    def test_stores_how_the_listing_charges_and_its_own_services(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = onboarding(
            client,
            user,
            listing=listing_data(
                pricing_model="per_hour",
                price_from_cents=40_000,
                minimum_price_cents=160_000,
                offers=[
                    {
                        "category": "buffet",
                        "name": "  Buffet   da casa ",
                        "description": "Almoço ou jantar.",
                        "pricing_model": "per_person",
                        "price_cents": 4_500,
                    },
                    {"category": "other", "name": "Taxa de limpeza", "price_cents": 15_000,
                     "required": True},
                    {"category": "decoration", "name": "Decoração", "pricing_model": "on_request"},
                ],
            ),
        )  # fmt: skip

        assert response.status_code == 201, response.text
        listing = response.json()["listing"]
        assert listing["pricing_model"] == "per_hour"
        assert listing["price_from_cents"] == 40_000
        assert listing["minimum_price_cents"] == 160_000
        assert [
            (o["name"], o["pricing_model"], o["price_cents"], o["required"])
            for o in listing["offers"]
        ] == [
            ("Buffet da casa", "per_person", 4_500, False),
            ("Taxa de limpeza", "fixed", 15_000, True),
            ("Decoração", "on_request", None, False),
        ]

    def test_a_listing_on_request_is_stored_without_a_price(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        listing = listing_data(pricing_model="on_request")
        del listing["price_from_cents"]

        response = onboarding(client, user, listing=listing)

        assert response.status_code == 201, response.text
        assert response.json()["listing"]["price_from_cents"] is None
        stored = db.scalar(select(Listing))
        assert stored is not None
        assert stored.price_from_cents == 0

    @pytest.mark.parametrize(
        "overrides",
        [
            {"pricing_model": "inexistente"},
            {"price_from_cents": 0},
            {"pricing_model": "on_request", "price_from_cents": 100_000},
            {"pricing_model": "on_request", "price_from_cents": 0, "minimum_price_cents": 1},
            {"minimum_price_cents": -1},
            {"offers": [{"category": "buffet", "name": "ab", "price_cents": 100}]},
            {"offers": [{"category": "buffet", "name": "Buffet", "price_cents": 0}]},
            {"offers": [{"category": "venue", "name": "Sala anexa", "price_cents": 100}]},
            {"offers": [{"category": "buffet", "name": "Buffet", "price_cents": 100}] * 21},
            {"partner_listing_ids": ["nao-e-uuid"]},
        ],
        ids=[
            "modelo desconhecido",
            "preço zero sem ser sob consulta",
            "sob consulta com preço",
            "sob consulta com mínimo",
            "mínimo negativo",
            "serviço com nome curto",
            "serviço de graça sem ser sob consulta",
            "serviço que é outro salão",
            "serviços demais",
            "parceiro com id inválido",
        ],
    )
    def test_rejects_incoherent_pricing_and_services(
        self, client: TestClient, user: AuthenticatedUser, overrides: dict[str, object]
    ) -> None:
        response = onboarding(client, user, listing=listing_data(**overrides))

        assert response.status_code == 422
        assert error_code(response) == "validation_error"

    def test_a_service_needs_a_known_category(
        self, client: TestClient, user: AuthenticatedUser, db: Session
    ) -> None:
        response = onboarding(
            client,
            user,
            listing=listing_data(
                offers=[{"category": "inexistente", "name": "Mágico", "price_cents": 100}]
            ),
        )

        assert response.status_code == 422
        assert error_code(response) == "unknown_category"
        assert db.scalar(select(Listing)) is None

    def test_recommends_published_listings_as_partners(
        self, client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
    ) -> None:
        band = create_listing(title="Banda Festa Boa", category="attraction")
        flowers = create_listing(title="Arte em Flores", category="decoration")

        response = onboarding(
            client,
            user,
            # Repetido de propósito: o mesmo parceiro entra uma vez só.
            listing=listing_data(partner_listing_ids=[str(band.id), str(flowers.id), str(band.id)]),
        )

        assert response.status_code == 201, response.text
        assert [p["title"] for p in response.json()["listing"]["partners"]] == [
            "Arte em Flores",
            "Banda Festa Boa",
        ]

    @pytest.mark.parametrize("status", [ListingStatus.PENDING_REVIEW, ListingStatus.ARCHIVED])
    def test_a_partner_has_to_be_published(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        create_listing: CreateListing,
        db: Session,
        status: ListingStatus,
    ) -> None:
        hidden = create_listing(category="attraction", status=status)

        response = onboarding(
            client, user, listing=listing_data(partner_listing_ids=[str(hidden.id)])
        )

        assert response.status_code == 422
        assert error_code(response) == "unknown_partner_listing"
        # Nem o anúncio nem o cadastro ficam para trás.
        assert db.scalar(select(VendorProfile).where(VendorProfile.user_id == user.id)) is None


class TestReview:
    def test_admin_routes_are_closed_to_regular_users(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]
        listing_id = client.get(MY_LISTINGS, headers=user.headers).json()["items"][0]["id"]
        attempts = [
            client.get(ADMIN_VENDORS, headers=user.headers),
            client.get(ADMIN_LISTINGS, headers=user.headers),
            # O próprio fornecedor tentando se aprovar.
            client.post(f"{ADMIN_VENDORS}/{vendor_id}/approve", headers=user.headers),
            client.post(
                f"{ADMIN_VENDORS}/{vendor_id}/reject",
                headers=user.headers,
                json={"reason": "motivo qualquer"},
            ),
            client.post(f"{ADMIN_LISTINGS}/{listing_id}/approve", headers=user.headers),
        ]

        assert [response.status_code for response in attempts] == [403] * 5
        assert client.get(ADMIN_VENDORS).status_code == 401

    def test_queue_shows_pending_vendors_with_the_full_document(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        onboarding(client, user)

        response = client.get(ADMIN_VENDORS, headers=admin.headers)

        assert response.status_code == 200
        (pending,) = response.json()["items"]
        assert pending["document"] == CPF
        assert pending["user_id"] == str(user.id)

    def test_approving_a_vendor_publishes_its_pending_listings(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()

        response = client.post(
            f"{ADMIN_VENDORS}/{created['vendor']['id']}/approve", headers=admin.headers
        )

        assert response.status_code == 200
        assert response.json()["status"] == "approved"
        assert client.get(MY_VENDOR, headers=user.headers).json()["status"] == "approved"
        catalog = client.get(CATALOG).json()["items"]
        assert [listing["id"] for listing in catalog] == [created["listing"]["id"]]
        assert client.get(ADMIN_VENDORS, headers=admin.headers).json()["items"] == []

    def test_vendor_can_be_approved_without_publishing_listings(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()

        client.post(
            f"{ADMIN_VENDORS}/{created['vendor']['id']}/approve",
            headers=admin.headers,
            json={"publish_pending_listings": False},
        )

        assert client.get(CATALOG).json()["items"] == []
        pending = client.get(ADMIN_LISTINGS, headers=admin.headers).json()["items"]
        assert [listing["id"] for listing in pending] == [created["listing"]["id"]]

    def test_listing_of_unapproved_vendor_cannot_be_published(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()

        response = client.post(
            f"{ADMIN_LISTINGS}/{created['listing']['id']}/approve", headers=admin.headers
        )

        assert response.status_code == 409
        assert error_code(response) == "vendor_not_approved"

    def test_listing_review_publishes_or_rejects(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()
        client.post(
            f"{ADMIN_VENDORS}/{created['vendor']['id']}/approve",
            headers=admin.headers,
            json={"publish_pending_listings": False},
        )
        second = onboarding(
            client, user, include_vendor=False, listing=listing_data(title="Segundo espaço")
        ).json()["listing"]

        approved = client.post(
            f"{ADMIN_LISTINGS}/{created['listing']['id']}/approve", headers=admin.headers
        )
        rejected = client.post(
            f"{ADMIN_LISTINGS}/{second['id']}/reject",
            headers=admin.headers,
            json={"reason": "Fotos insuficientes."},
        )

        assert approved.json()["status"] == "published"
        assert rejected.json()["status"] == "rejected"
        assert rejected.json()["rejection_reason"] == "Fotos insuficientes."
        assert [listing["title"] for listing in client.get(CATALOG).json()["items"]] == [
            "Espaço Crystal"
        ]

    def test_rejected_vendor_sees_the_reason_and_can_resubmit(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        admin: AuthenticatedUser,
        db: Session,
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]
        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )
        rejected = client.get(MY_VENDOR, headers=user.headers).json()

        resubmitted = onboarding(client, user, vendor=vendor_data(legal_name="Maria de Oliveira"))

        assert rejected["status"] == "rejected"
        assert rejected["rejection_reason"] == "Documento ilegível."
        assert resubmitted.status_code == 201
        assert resubmitted.json()["vendor"]["status"] == "pending_review"
        assert resubmitted.json()["vendor"]["rejection_reason"] is None
        assert resubmitted.json()["vendor"]["legal_name"] == "Maria de Oliveira"
        stored = db.scalar(select(VendorProfile))
        assert stored is not None
        assert stored.status is VendorStatus.PENDING_REVIEW
        assert stored.reviewed_by is None

    def test_rejecting_a_vendor_rejects_the_listings_waiting_with_it(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]

        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )

        (listing,) = client.get(MY_LISTINGS, headers=user.headers).json()["items"]
        assert listing["status"] == "rejected"
        assert listing["rejection_reason"] == "Documento ilegível."
        # Sem o cadastro o anúncio não tem como ser publicado: não fica na fila.
        assert client.get(ADMIN_LISTINGS, headers=admin.headers).json()["items"] == []

    def test_resubmission_does_not_publish_the_listing_rejected_with_the_vendor(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        # Regressão: o anúncio do primeiro envio continuava "em análise" depois
        # da recusa do cadastro; ao corrigir e reenviar, a aprovação publicava
        # os dois, e o mesmo salão aparecia duas vezes no catálogo.
        vendor_id = onboarding(client, user).json()["vendor"]["id"]
        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )
        resubmitted = onboarding(client, user).json()

        client.post(f"{ADMIN_VENDORS}/{vendor_id}/approve", headers=admin.headers)

        catalog = client.get(CATALOG).json()["items"]
        assert [listing["id"] for listing in catalog] == [resubmitted["listing"]["id"]]

    def test_rejecting_a_vendor_leaves_the_listings_of_other_vendors_alone(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        other_user: AuthenticatedUser,
        admin: AuthenticatedUser,
    ) -> None:
        other_vendor = onboarding(
            client, other_user, vendor=vendor_data(document=VALID_CPFS[2])
        ).json()["vendor"]
        vendor_id = onboarding(client, user).json()["vendor"]["id"]

        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )

        # Só os anúncios do cadastro recusado saem da fila.
        (still_pending,) = client.get(ADMIN_LISTINGS, headers=admin.headers).json()["items"]
        assert still_pending["vendor_id"] == other_vendor["id"]

    def test_rejecting_a_vendor_rejects_every_listing_waiting_with_it(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]
        # Quem ainda aguarda a análise pode enviar outro anúncio.
        onboarding(client, user, include_vendor=False, listing=listing_data(title="Segundo espaço"))

        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )

        listings = client.get(MY_LISTINGS, headers=user.headers).json()["items"]
        assert [(listing["status"], listing["rejection_reason"]) for listing in listings] == [
            ("rejected", "Documento ilegível."),
            ("rejected", "Documento ilegível."),
        ]
        assert client.get(ADMIN_LISTINGS, headers=admin.headers).json()["items"] == []

    def test_a_second_rejection_keeps_the_reason_of_listings_rejected_before(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        # Só os anúncios que aguardam mudam: o do primeiro envio já tinha sido
        # recusado, e continua com o motivo daquela vez.
        first = onboarding(client, user).json()
        vendor_id = first["vendor"]["id"]
        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Documento ilegível."},
        )
        second = onboarding(client, user).json()["listing"]

        client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "O nome não confere com o documento."},
        )

        listings = client.get(MY_LISTINGS, headers=user.headers).json()["items"]
        assert {listing["id"]: listing["rejection_reason"] for listing in listings} == {
            first["listing"]["id"]: "Documento ilegível.",
            second["id"]: "O nome não confere com o documento.",
        }

    def test_listing_queue_says_whose_listing_it_is(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()

        (pending,) = client.get(ADMIN_LISTINGS, headers=admin.headers).json()["items"]

        assert pending["id"] == created["listing"]["id"]
        assert pending["vendor_id"] == created["vendor"]["id"]
        assert pending["vendor_legal_name"] == "Maria Oliveira"
        assert pending["vendor_status"] == "pending_review"
        assert pending["created_at"] is not None
        # O documento do fornecedor fica só na fila de cadastros.
        assert "document" not in pending

    def test_a_listing_decision_answers_with_the_vendor_too(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        created = onboarding(client, user).json()
        client.post(
            f"{ADMIN_VENDORS}/{created['vendor']['id']}/approve",
            headers=admin.headers,
            json={"publish_pending_listings": False},
        )

        approved = client.post(
            f"{ADMIN_LISTINGS}/{created['listing']['id']}/approve", headers=admin.headers
        ).json()

        assert approved["status"] == "published"
        assert approved["vendor_status"] == "approved"
        assert approved["vendor_legal_name"] == "Maria Oliveira"

    def test_a_decision_cannot_be_made_twice(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]
        client.post(f"{ADMIN_VENDORS}/{vendor_id}/approve", headers=admin.headers)

        again = client.post(f"{ADMIN_VENDORS}/{vendor_id}/approve", headers=admin.headers)
        reject = client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject",
            headers=admin.headers,
            json={"reason": "Mudei de ideia."},
        )

        assert again.status_code == reject.status_code == 409
        assert error_code(again) == "already_reviewed"

    def test_rejection_requires_a_reason(
        self, client: TestClient, user: AuthenticatedUser, admin: AuthenticatedUser
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]

        response = client.post(
            f"{ADMIN_VENDORS}/{vendor_id}/reject", headers=admin.headers, json={"reason": " "}
        )

        assert response.status_code == 422

    def test_unknown_ids_are_404(self, client: TestClient, admin: AuthenticatedUser) -> None:
        vendor = client.post(f"{ADMIN_VENDORS}/{uuid.uuid4()}/approve", headers=admin.headers)
        listing = client.post(f"{ADMIN_LISTINGS}/{uuid.uuid4()}/approve", headers=admin.headers)

        assert vendor.status_code == listing.status_code == 404

    def test_records_who_reviewed(
        self,
        client: TestClient,
        user: AuthenticatedUser,
        admin: AuthenticatedUser,
        db: Session,
    ) -> None:
        vendor_id = onboarding(client, user).json()["vendor"]["id"]

        client.post(f"{ADMIN_VENDORS}/{vendor_id}/approve", headers=admin.headers)

        stored = db.get_one(VendorProfile, uuid.UUID(vendor_id))
        assert stored.reviewed_by == admin.id
        assert stored.reviewed_at is not None
