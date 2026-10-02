import uuid
from datetime import datetime

from sqlalchemy import ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base, UTCDateTime, utcnow


class Favorite(Base):
    __tablename__ = "favorites"

    # A chave composta garante que um anúncio não é favoritado duas vezes e já
    # serve de índice para "favoritos do usuário"; como há um teto por usuário,
    # ordenar por data não precisa de índice próprio.
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    # Índice para o ON DELETE CASCADE quando um anúncio é apagado.
    listing_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("listings.id", ondelete="CASCADE"), primary_key=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(UTCDateTime, default=utcnow)
