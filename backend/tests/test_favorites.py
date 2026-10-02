import uuid

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.modules.catalog.models import ListingStatus
from app.modules.favorites import service as favorites_service
from app.modules.favorites.models import Favorite
from tests.conftest import AuthenticatedUser, CreateListing

FAVORITES = "/api/v1/favorites"


def favorite_ids(client: TestClient, user: AuthenticatedUser) -> list[str]:
    response = client.get(FAVORITES, headers=user.headers)
    assert response.status_code == 200
    return [item["id"] for item in response.json()["items"]]


def test_requires_authentication(client: TestClient, create_listing: CreateListing) -> None:
    listing = create_listing()

    assert client.get(FAVORITES).status_code == 401
    assert client.put(f"{FAVORITES}/{listing.id}").status_code == 401
    assert client.delete(f"{FAVORITES}/{listing.id}").status_code == 401


def test_starts_empty(client: TestClient, user: AuthenticatedUser) -> None:
    assert favorite_ids(client, user) == []


def test_adds_and_lists_most_recent_first(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
) -> None:
    first = create_listing(title="Primeiro")
    second = create_listing(title="Segundo")

    assert client.put(f"{FAVORITES}/{first.id}", headers=user.headers).status_code == 204
    assert client.put(f"{FAVORITES}/{second.id}", headers=user.headers).status_code == 204

    assert favorite_ids(client, user) == [str(second.id), str(first.id)]


def test_adding_twice_keeps_a_single_favorite(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing, db: Session
) -> None:
    listing = create_listing()

    client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)
    repeated = client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)

    assert repeated.status_code == 204
    assert db.scalar(select(func.count()).select_from(Favorite)) == 1


def test_removes_and_is_idempotent(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
) -> None:
    listing = create_listing()
    client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)

    assert client.delete(f"{FAVORITES}/{listing.id}", headers=user.headers).status_code == 204
    assert client.delete(f"{FAVORITES}/{listing.id}", headers=user.headers).status_code == 204
    assert favorite_ids(client, user) == []


def test_cannot_favorite_unknown_or_unpublished_listing(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing
) -> None:
    pending = create_listing(status=ListingStatus.PENDING_REVIEW)

    unknown = client.put(f"{FAVORITES}/{uuid.uuid4()}", headers=user.headers)
    unpublished = client.put(f"{FAVORITES}/{pending.id}", headers=user.headers)

    assert unknown.status_code == unpublished.status_code == 404
    assert unknown.json()["error"]["code"] == "listing_not_found"


def test_favorites_are_private_to_each_user(
    client: TestClient,
    user: AuthenticatedUser,
    other_user: AuthenticatedUser,
    create_listing: CreateListing,
) -> None:
    listing = create_listing()
    client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)

    assert favorite_ids(client, other_user) == []
    # Remover pela conta de outra pessoa não afeta o favorito do dono.
    client.delete(f"{FAVORITES}/{listing.id}", headers=other_user.headers)
    assert favorite_ids(client, user) == [str(listing.id)]


def test_listing_that_leaves_the_catalog_disappears_from_favorites(
    client: TestClient, user: AuthenticatedUser, create_listing: CreateListing, db: Session
) -> None:
    listing = create_listing()
    client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)

    listing.status = ListingStatus.ARCHIVED
    db.commit()

    assert favorite_ids(client, user) == []


def test_enforces_a_limit_per_user(
    client: TestClient,
    user: AuthenticatedUser,
    create_listing: CreateListing,
    monkeypatch,
) -> None:
    monkeypatch.setattr(favorites_service, "MAX_FAVORITES_PER_USER", 2)
    listings = [create_listing() for _ in range(3)]
    for listing in listings[:2]:
        client.put(f"{FAVORITES}/{listing.id}", headers=user.headers)

    response = client.put(f"{FAVORITES}/{listings[2].id}", headers=user.headers)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "favorites_limit_reached"
