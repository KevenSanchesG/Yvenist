"""Importa todos os modelos para registrá-los em ``Base.metadata``.

O Alembic e o ``create_all`` dos testes só enxergam as tabelas dos módulos que
já foram importados; este arquivo é o ponto único que garante isso.
"""

from app.core.database import Base
from app.modules.accounts.models import RefreshToken, User
from app.modules.catalog.models import (
    Category,
    EventType,
    Listing,
    ListingOffer,
    listing_event_types,
    listing_partners,
)
from app.modules.favorites.models import Favorite
from app.modules.parties.models import Party, PartyItem, PartySnapshot
from app.modules.vendors.models import VendorProfile

__all__ = [
    "Base",
    "Category",
    "EventType",
    "Favorite",
    "Listing",
    "ListingOffer",
    "Party",
    "PartyItem",
    "PartySnapshot",
    "RefreshToken",
    "User",
    "VendorProfile",
    "listing_event_types",
    "listing_partners",
]
