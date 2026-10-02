"""Consulta ao catálogo público: só anúncios publicados aparecem aqui."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from enum import StrEnum

from sqlalchemy import ColumnElement, Select, and_, exists, or_, select
from sqlalchemy.orm import Session, selectinload

from app.core.errors import NotFoundError
from app.core.pagination import Cursor, InvalidCursorError, decode_cursor, encode_cursor
from app.modules.catalog.models import (
    Category,
    EventType,
    Listing,
    ListingStatus,
    listing_event_types,
)
from app.modules.catalog.text import normalize_text

_EPOCH = datetime(1970, 1, 1, tzinfo=UTC)
_ONE_MICROSECOND = timedelta(microseconds=1)
_INT64_LIMIT = 2**63


class ListingSort(StrEnum):
    POPULAR = "popular"
    PRICE_ASC = "price_asc"
    PRICE_DESC = "price_desc"
    RECENT = "recent"


class ListingNotFoundError(NotFoundError):
    code = "listing_not_found"
    message = "Anúncio não encontrado."


@dataclass(frozen=True)
class ListingFilters:
    query: str | None = None
    category: str | None = None
    event_type: str | None = None
    min_price_cents: int | None = None
    max_price_cents: int | None = None


def _to_micros(value: datetime) -> int:
    return (value - _EPOCH) // _ONE_MICROSECOND


def _from_micros(value: int) -> datetime:
    return _EPOCH + timedelta(microseconds=value)


class CatalogService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_categories(self) -> list[Category]:
        return list(
            self._db.scalars(
                select(Category).where(Category.is_active).order_by(Category.sort_order)
            )
        )

    def list_event_types(self) -> list[EventType]:
        return list(
            self._db.scalars(
                select(EventType).where(EventType.is_active).order_by(EventType.sort_order)
            )
        )

    def search_listings(
        self,
        filters: ListingFilters,
        *,
        sort: ListingSort,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[Listing], str | None]:
        statement = self._apply_filters(
            select(Listing).where(Listing.status == ListingStatus.PUBLISHED), filters
        )
        if cursor is not None:
            statement = statement.where(
                self._after_cursor(sort, decode_cursor(cursor, expected_sort=sort.value))
            )
        statement = self._apply_order(statement, sort)

        # Busca um item a mais só para saber se existe próxima página.
        rows = list(self._db.scalars(statement.limit(limit + 1)))
        if len(rows) <= limit:
            return rows, None

        page = rows[:limit]
        return page, encode_cursor(self._cursor_for(sort, page[-1]))

    def get_published_listing(self, listing_id: uuid.UUID) -> Listing:
        listing = self._db.scalar(
            select(Listing)
            .where(Listing.id == listing_id, Listing.status == ListingStatus.PUBLISHED)
            .options(selectinload(Listing.event_types))
        )
        if listing is None:
            raise ListingNotFoundError
        return listing

    # ------------------------------------------------------------------

    @staticmethod
    def _apply_filters(statement: Select[Listing], filters: ListingFilters) -> Select[Listing]:
        if filters.query:
            term = normalize_text(filters.query)
            if term:
                # autoescape trata % e _ digitados pelo usuário como texto comum.
                statement = statement.where(Listing.search_text.contains(term, autoescape=True))
        if filters.category:
            statement = statement.where(Listing.category_slug == filters.category)
        if filters.event_type:
            statement = statement.where(
                exists().where(
                    listing_event_types.c.listing_id == Listing.id,
                    listing_event_types.c.event_type_slug == filters.event_type,
                )
            )
        if filters.min_price_cents is not None:
            statement = statement.where(Listing.price_from_cents >= filters.min_price_cents)
        if filters.max_price_cents is not None:
            statement = statement.where(Listing.price_from_cents <= filters.max_price_cents)
        return statement

    @staticmethod
    def _apply_order(statement: Select[Listing], sort: ListingSort) -> Select[Listing]:
        # O id entra como desempate para a ordem ser total: sem isso, itens com
        # a mesma chave poderiam se repetir ou sumir entre páginas.
        match sort:
            case ListingSort.POPULAR:
                return statement.order_by(Listing.rating_count.desc(), Listing.id)
            case ListingSort.PRICE_ASC:
                return statement.order_by(Listing.price_from_cents, Listing.id)
            case ListingSort.PRICE_DESC:
                return statement.order_by(Listing.price_from_cents.desc(), Listing.id)
            case ListingSort.RECENT:
                return statement.order_by(Listing.published_at.desc(), Listing.id)

    @staticmethod
    def _cursor_for(sort: ListingSort, listing: Listing) -> Cursor:
        match sort:
            case ListingSort.POPULAR:
                key: int = listing.rating_count
            case ListingSort.PRICE_ASC | ListingSort.PRICE_DESC:
                key = listing.price_from_cents
            case ListingSort.RECENT:
                # Publicado sempre tem data (garantido por CHECK no banco).
                key = _to_micros(listing.published_at or _EPOCH)
        return Cursor(sort=sort.value, key=key, id=listing.id)

    @staticmethod
    def _after_cursor(sort: ListingSort, cursor: Cursor) -> ColumnElement[bool]:
        """Condição "vem depois do último item da página anterior"."""
        key = cursor.key
        if not isinstance(key, int) or abs(key) >= _INT64_LIMIT:
            raise InvalidCursorError

        after_tie = Listing.id > cursor.id
        match sort:
            case ListingSort.POPULAR:
                return or_(
                    Listing.rating_count < key,
                    and_(Listing.rating_count == key, after_tie),
                )
            case ListingSort.PRICE_ASC:
                return or_(
                    Listing.price_from_cents > key,
                    and_(Listing.price_from_cents == key, after_tie),
                )
            case ListingSort.PRICE_DESC:
                return or_(
                    Listing.price_from_cents < key,
                    and_(Listing.price_from_cents == key, after_tie),
                )
            case ListingSort.RECENT:
                try:
                    published_at = _from_micros(key)
                except OverflowError as exc:
                    raise InvalidCursorError from exc
                return or_(
                    Listing.published_at < published_at,
                    and_(Listing.published_at == published_at, after_tie),
                )
