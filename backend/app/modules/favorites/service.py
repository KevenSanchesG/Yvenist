import uuid

from sqlalchemy import delete, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import ConflictError
from app.modules.accounts.models import User
from app.modules.catalog.models import Listing, ListingStatus
from app.modules.catalog.service import ListingNotFoundError
from app.modules.favorites.models import Favorite

# Teto por usuário: mantém a lista (e a resposta de ids) com tamanho previsível.
MAX_FAVORITES_PER_USER = 500


class FavoritesLimitReachedError(ConflictError):
    code = "favorites_limit_reached"
    message = f"Você atingiu o limite de {MAX_FAVORITES_PER_USER} favoritos."


class FavoriteService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_listings(self, user: User) -> list[Listing]:
        """Anúncios favoritados que continuam publicados, do mais recente ao mais antigo."""
        return list(
            self._db.scalars(
                select(Listing)
                .join(Favorite, Favorite.listing_id == Listing.id)
                .where(Favorite.user_id == user.id, Listing.status == ListingStatus.PUBLISHED)
                .order_by(Favorite.created_at.desc(), Listing.id)
            )
        )

    def add(self, user: User, listing_id: uuid.UUID) -> None:
        """Favorita o anúncio. Repetir a chamada não tem efeito."""
        if self._db.get(Favorite, (user.id, listing_id)) is not None:
            return

        is_published = self._db.scalar(
            select(Listing.id).where(
                Listing.id == listing_id, Listing.status == ListingStatus.PUBLISHED
            )
        )
        if is_published is None:
            raise ListingNotFoundError

        total = self._db.scalar(
            select(func.count()).select_from(Favorite).where(Favorite.user_id == user.id)
        )
        if total is not None and total >= MAX_FAVORITES_PER_USER:
            raise FavoritesLimitReachedError

        self._db.add(Favorite(user_id=user.id, listing_id=listing_id))
        try:
            self._db.commit()
        except IntegrityError:
            # Duas chamadas simultâneas: a outra já favoritou. O resultado é o mesmo.
            self._db.rollback()

    def remove(self, user: User, listing_id: uuid.UUID) -> None:
        """Remove o favorito. Não falha se ele não existir."""
        self._db.execute(
            delete(Favorite).where(Favorite.user_id == user.id, Favorite.listing_id == listing_id)
        )
        self._db.commit()
