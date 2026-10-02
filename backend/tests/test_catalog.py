import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.orm import Session

from app.core.pagination import Cursor, encode_cursor
from app.modules.catalog.models import ListingStatus
from app.modules.catalog.reference_data import CATEGORIES, EVENT_TYPES
from tests.conftest import CreateListing

LISTINGS = "/api/v1/catalog/listings"


def titles(response) -> list[str]:
    return [item["title"] for item in response.json()["items"]]


class TestReferenceData:
    def test_lists_categories_in_display_order(self, client: TestClient) -> None:
        response = client.get("/api/v1/catalog/categories")

        assert response.status_code == 200
        assert [c["slug"] for c in response.json()] == [c["slug"] for c in CATEGORIES]
        assert response.json()[0] == {"slug": "venue", "name": "Salões", "icon": "venue"}

    def test_lists_event_types(self, client: TestClient) -> None:
        response = client.get("/api/v1/catalog/event-types")

        assert [e["slug"] for e in response.json()] == [e["slug"] for e in EVENT_TYPES]

    def test_catalog_is_public(self, client: TestClient) -> None:
        assert client.get(LISTINGS).status_code == 200


class TestSearch:
    def test_returns_the_card_fields(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        listing = create_listing(title="Salão Glamour", price_from_cents=150_000, rating_count=12)

        response = client.get(LISTINGS)

        assert response.status_code == 200
        assert response.json() == {
            "items": [
                {
                    "id": str(listing.id),
                    "title": "Salão Glamour",
                    "category": "venue",
                    "neighborhood": "Campo Grande",
                    "city": "Rio de Janeiro",
                    "state": "RJ",
                    "price_from_cents": 150_000,
                    "currency": "BRL",
                    "cover_image_url": "https://example.com/capa.jpg",
                    "rating_average": 4.8,
                    "rating_count": 12,
                }
            ],
            "next_cursor": None,
        }

    @pytest.mark.parametrize(
        "status",
        [
            ListingStatus.DRAFT,
            ListingStatus.PENDING_REVIEW,
            ListingStatus.REJECTED,
            ListingStatus.ARCHIVED,
        ],
    )
    def test_only_published_listings_are_visible(
        self, client: TestClient, create_listing: CreateListing, status: ListingStatus
    ) -> None:
        hidden = create_listing(status=status)

        assert client.get(LISTINGS).json()["items"] == []
        assert client.get(f"{LISTINGS}/{hidden.id}").status_code == 404

    def test_filters_by_category(self, client: TestClient, create_listing: CreateListing) -> None:
        create_listing(title="Salão", category="venue")
        create_listing(title="Banda", category="attraction")

        response = client.get(LISTINGS, params={"category": "attraction"})

        assert titles(response) == ["Banda"]

    def test_filters_by_event_type(self, client: TestClient, create_listing: CreateListing) -> None:
        create_listing(title="Casamentos e formaturas", event_types=("wedding", "graduation"))
        create_listing(title="Só infantil", event_types=("kids_party",))

        response = client.get(LISTINGS, params={"event_type": "wedding"})

        assert titles(response) == ["Casamentos e formaturas"]

    def test_filters_by_price_range(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        create_listing(title="Barato", price_from_cents=50_000)
        create_listing(title="Médio", price_from_cents=100_000)
        create_listing(title="Caro", price_from_cents=300_000)

        response = client.get(
            LISTINGS,
            params={"min_price_cents": 60_000, "max_price_cents": 200_000},
        )

        assert titles(response) == ["Médio"]

    @pytest.mark.parametrize("term", ["salao", "SALÃO", "  salão  glamour ", "campo grande"])
    def test_search_ignores_accents_case_and_spacing(
        self, client: TestClient, create_listing: CreateListing, term: str
    ) -> None:
        create_listing(title="Salão Glamour", neighborhood="Campo Grande")
        create_listing(title="Banda Festa Boa", category="attraction", neighborhood="Tijuca")

        response = client.get(LISTINGS, params={"q": term})

        assert titles(response) == ["Salão Glamour"]

    def test_search_also_matches_the_category_name(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        create_listing(title="Espaço Crystal", category="venue")
        create_listing(title="Tio do Algodão Doce", category="buffet")

        assert titles(client.get(LISTINGS, params={"q": "saloes"})) == ["Espaço Crystal"]

    @pytest.mark.parametrize("term", ["%", "_", "100%", "a_b", "'; DROP TABLE listings; --"])
    def test_search_treats_wildcards_and_sql_as_plain_text(
        self, client: TestClient, create_listing: CreateListing, term: str
    ) -> None:
        create_listing(title="Salão Glamour")

        response = client.get(LISTINGS, params={"q": term})

        assert response.status_code == 200
        assert response.json()["items"] == []
        # A tabela continua lá e intacta.
        assert len(client.get(LISTINGS).json()["items"]) == 1


class TestSorting:
    def test_popular_is_the_default(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        create_listing(title="Pouco avaliado", rating_count=2)
        create_listing(title="Muito avaliado", rating_count=90)
        create_listing(title="Sem avaliações", rating_count=0)

        assert titles(client.get(LISTINGS)) == [
            "Muito avaliado",
            "Pouco avaliado",
            "Sem avaliações",
        ]

    def test_by_price(self, client: TestClient, create_listing: CreateListing) -> None:
        create_listing(title="Médio", price_from_cents=100_000)
        create_listing(title="Barato", price_from_cents=50_000)
        create_listing(title="Caro", price_from_cents=300_000)

        ascending = client.get(LISTINGS, params={"sort": "price_asc"})
        descending = client.get(LISTINGS, params={"sort": "price_desc"})

        assert titles(ascending) == ["Barato", "Médio", "Caro"]
        assert titles(descending) == ["Caro", "Médio", "Barato"]

    def test_most_recent_first(self, client: TestClient, create_listing: CreateListing) -> None:
        create_listing(title="Antigo", published_minutes_ago=60)
        create_listing(title="Novo", published_minutes_ago=1)
        create_listing(title="Intermediário", published_minutes_ago=30)

        response = client.get(LISTINGS, params={"sort": "recent"})

        assert titles(response) == ["Novo", "Intermediário", "Antigo"]


class TestPagination:
    @pytest.mark.parametrize("sort", ["popular", "price_asc", "price_desc", "recent"])
    def test_walks_every_item_exactly_once(
        self, client: TestClient, create_listing: CreateListing, sort: str
    ) -> None:
        # Vários itens com a mesma chave de ordenação: o desempate por id é o
        # que garante que nada se repete nem some entre as páginas.
        for index in range(7):
            create_listing(
                price_from_cents=100_000 if index < 4 else 200_000,
                rating_count=5 if index % 2 else 0,
                published_minutes_ago=index // 2,
            )
        expected = [
            item["id"] for item in client.get(LISTINGS, params={"sort": sort}).json()["items"]
        ]

        collected: list[str] = []
        cursor = None
        pages = 0
        while True:
            params: dict[str, str | int] = {"sort": sort, "limit": 3}
            if cursor:
                params["cursor"] = cursor
            body = client.get(LISTINGS, params=params).json()
            collected.extend(item["id"] for item in body["items"])
            pages += 1
            cursor = body["next_cursor"]
            if cursor is None:
                break

        assert pages == 3
        assert collected == expected
        assert len(set(collected)) == 7

    def test_last_page_has_no_cursor(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        for _ in range(3):
            create_listing()

        exact = client.get(LISTINGS, params={"limit": 3}).json()

        assert len(exact["items"]) == 3
        assert exact["next_cursor"] is None

    def test_filters_apply_to_every_page(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        for index in range(4):
            create_listing(title=f"Salão {index}", category="venue")
            create_listing(title=f"Banda {index}", category="attraction")

        first = client.get(LISTINGS, params={"category": "venue", "limit": 3}).json()
        second = client.get(
            LISTINGS, params={"category": "venue", "limit": 3, "cursor": first["next_cursor"]}
        ).json()

        assert all(item["category"] == "venue" for item in first["items"] + second["items"])
        assert len(first["items"]) + len(second["items"]) == 4

    @pytest.mark.parametrize("limit", [0, 51, -1])
    def test_limit_is_bounded(self, client: TestClient, limit: int) -> None:
        assert client.get(LISTINGS, params={"limit": limit}).status_code == 422

    @pytest.mark.parametrize(
        "cursor",
        [
            "lixo",
            encode_cursor(Cursor(sort="popular", key="texto", id=uuid.uuid4())),
            encode_cursor(Cursor(sort="popular", key=2**70, id=uuid.uuid4())),
            encode_cursor(Cursor(sort="popular", key=1.5, id=uuid.uuid4())),
        ],
        ids=["não é json", "chave de texto", "chave fora do intervalo", "chave decimal"],
    )
    def test_rejects_invalid_cursor(self, client: TestClient, cursor: str) -> None:
        response = client.get(LISTINGS, params={"cursor": cursor})

        assert response.status_code == 422
        assert response.json()["error"]["code"] == "invalid_cursor"

    def test_rejects_out_of_range_date_cursor(self, client: TestClient) -> None:
        cursor = encode_cursor(Cursor(sort="recent", key=2**62, id=uuid.uuid4()))

        response = client.get(LISTINGS, params={"sort": "recent", "cursor": cursor})

        assert response.status_code == 422
        assert response.json()["error"]["code"] == "invalid_cursor"

    def test_cursor_from_one_sort_is_rejected_by_another(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        for _ in range(3):
            create_listing()
        cursor = client.get(LISTINGS, params={"limit": 2}).json()["next_cursor"]

        response = client.get(LISTINGS, params={"sort": "price_asc", "cursor": cursor})

        assert response.status_code == 422


class TestDetail:
    def test_returns_the_full_listing(
        self, client: TestClient, create_listing: CreateListing
    ) -> None:
        listing = create_listing(event_types=("graduation", "wedding"))

        response = client.get(f"{LISTINGS}/{listing.id}")

        assert response.status_code == 200
        body = response.json()
        assert body["id"] == str(listing.id)
        assert body["description"].startswith("Espaço completo")
        # Na ordem de exibição dos tipos de evento, não na de inserção.
        assert body["event_types"] == ["wedding", "graduation"]
        assert body["cancellation_policy"] == "flexible"
        assert body["amenities"] == []

    def test_unknown_listing_is_404(self, client: TestClient) -> None:
        response = client.get(f"{LISTINGS}/{uuid.uuid4()}")

        assert response.status_code == 404
        assert response.json()["error"]["code"] == "listing_not_found"

    def test_malformed_id_is_422(self, client: TestClient) -> None:
        assert client.get(f"{LISTINGS}/nao-e-uuid").status_code == 422


def test_listing_page_costs_a_single_query(
    client: TestClient, create_listing: CreateListing, db: Session
) -> None:
    """Garante que a vitrine não cai em N+1: uma consulta, não uma por anúncio."""
    for _ in range(10):
        create_listing(event_types=("wedding",))

    statements: list[str] = []

    def record(_conn, _cursor, statement, *_args) -> None:
        statements.append(statement)

    engine = db.get_bind()
    event.listen(engine, "before_cursor_execute", record)
    try:
        response = client.get(LISTINGS)
    finally:
        event.remove(engine, "before_cursor_execute", record)

    assert len(response.json()["items"]) == 10
    selects = [s for s in statements if s.lstrip().upper().startswith("SELECT")]
    assert len(selects) == 1
