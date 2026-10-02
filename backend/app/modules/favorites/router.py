import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from pydantic import BaseModel

from app.api.deps import CurrentUser, DbSession
from app.modules.catalog.schemas import ListingSummary
from app.modules.favorites.service import FavoriteService

router = APIRouter(prefix="/favorites", tags=["Favoritos"])


class FavoritesResponse(BaseModel):
    items: list[ListingSummary]


def get_favorite_service(db: DbSession) -> FavoriteService:
    return FavoriteService(db)


FavoriteServiceDep = Annotated[FavoriteService, Depends(get_favorite_service)]


@router.get("", summary="Anúncios favoritados pelo usuário")
def list_favorites(user: CurrentUser, service: FavoriteServiceDep) -> FavoritesResponse:
    return FavoritesResponse(
        items=[ListingSummary.from_listing(listing) for listing in service.list_listings(user)]
    )


@router.put(
    "/{listing_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Favorita um anúncio (idempotente)",
)
def add_favorite(listing_id: uuid.UUID, user: CurrentUser, service: FavoriteServiceDep) -> Response:
    service.add(user, listing_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete(
    "/{listing_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remove um favorito (idempotente)",
)
def remove_favorite(
    listing_id: uuid.UUID,
    user: CurrentUser,
    service: FavoriteServiceDep,
) -> Response:
    service.remove(user, listing_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
