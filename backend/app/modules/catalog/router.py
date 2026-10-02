import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import DbSession
from app.core.pagination import DEFAULT_PAGE_SIZE, MAX_PAGE_SIZE
from app.modules.catalog.schemas import (
    CategoryResponse,
    EventTypeResponse,
    ListingDetail,
    ListingPage,
    ListingSummary,
)
from app.modules.catalog.service import CatalogService, ListingFilters, ListingSort

router = APIRouter(prefix="/catalog", tags=["Catálogo"])

# Limite do valor em centavos aceito nos filtros (R$ 1 milhão).
_MAX_PRICE_CENTS = 100_000_000


def get_catalog_service(db: DbSession) -> CatalogService:
    return CatalogService(db)


CatalogServiceDep = Annotated[CatalogService, Depends(get_catalog_service)]


@router.get("/categories", summary="Categorias de anúncio")
def list_categories(service: CatalogServiceDep) -> list[CategoryResponse]:
    return [CategoryResponse.model_validate(c) for c in service.list_categories()]


@router.get("/event-types", summary="Tipos de evento")
def list_event_types(service: CatalogServiceDep) -> list[EventTypeResponse]:
    return [EventTypeResponse.model_validate(e) for e in service.list_event_types()]


@router.get("/listings", summary="Busca anúncios publicados")
def search_listings(
    service: CatalogServiceDep,
    q: Annotated[str | None, Query(max_length=80, description="Texto livre.")] = None,
    category: Annotated[str | None, Query(max_length=40)] = None,
    event_type: Annotated[str | None, Query(max_length=40)] = None,
    min_price_cents: Annotated[int | None, Query(ge=0, le=_MAX_PRICE_CENTS)] = None,
    max_price_cents: Annotated[int | None, Query(ge=0, le=_MAX_PRICE_CENTS)] = None,
    sort: ListingSort = ListingSort.POPULAR,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
    cursor: Annotated[str | None, Query(max_length=300)] = None,
) -> ListingPage:
    listings, next_cursor = service.search_listings(
        ListingFilters(
            query=q,
            category=category,
            event_type=event_type,
            min_price_cents=min_price_cents,
            max_price_cents=max_price_cents,
        ),
        sort=sort,
        limit=limit,
        cursor=cursor,
    )
    return ListingPage(
        items=[ListingSummary.from_listing(listing) for listing in listings],
        next_cursor=next_cursor,
    )


@router.get("/listings/{listing_id}", summary="Detalhe de um anúncio publicado")
def get_listing(listing_id: uuid.UUID, service: CatalogServiceDep) -> ListingDetail:
    return ListingDetail.from_listing(service.get_published_listing(listing_id))
