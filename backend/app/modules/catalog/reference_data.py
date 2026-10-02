"""Dados de referência do catálogo.

São criados pela migração inicial. Ficam aqui também para os testes montarem o
banco sem rodar migrações, e um teste garante que as duas fontes não divergem.
"""

from typing import TypedDict

VENUE_CATEGORY = "venue"


class CategorySeed(TypedDict):
    slug: str
    name: str
    icon: str
    sort_order: int


class EventTypeSeed(TypedDict):
    slug: str
    name: str
    sort_order: int


CATEGORIES: tuple[CategorySeed, ...] = (
    {"slug": "venue", "name": "Salões", "icon": "venue", "sort_order": 10},
    {"slug": "attraction", "name": "Atrações", "icon": "attraction", "sort_order": 20},
    {"slug": "kids", "name": "Brinquedos", "icon": "kids", "sort_order": 30},
    {"slug": "buffet", "name": "Buffet e Bar", "icon": "buffet", "sort_order": 40},
    {"slug": "decoration", "name": "Decorações", "icon": "decoration", "sort_order": 50},
    {"slug": "beauty", "name": "Beleza", "icon": "beauty", "sort_order": 60},
    {"slug": "dj", "name": "DJ e Som", "icon": "dj", "sort_order": 70},
    {"slug": "staff", "name": "Equipe", "icon": "staff", "sort_order": 80},
    {"slug": "security", "name": "Segurança", "icon": "security", "sort_order": 90},
    {"slug": "other", "name": "Outros", "icon": "other", "sort_order": 100},
)

EVENT_TYPES: tuple[EventTypeSeed, ...] = (
    {"slug": "wedding", "name": "Casamentos", "sort_order": 10},
    {"slug": "debutante", "name": "15 anos", "sort_order": 20},
    {"slug": "kids_party", "name": "Infantil", "sort_order": 30},
    {"slug": "corporate", "name": "Corporativo", "sort_order": 40},
    {"slug": "barbecue", "name": "Churrasco", "sort_order": 50},
    {"slug": "graduation", "name": "Formatura", "sort_order": 60},
)

# Comodidades que um anúncio pode declarar. O app tem o rótulo e o ícone de
# cada uma; a API só valida a chave.
AMENITIES: frozenset[str] = frozenset(
    {"kitchen", "air_conditioning", "parking", "kids_area", "wifi", "accessibility"}
)

BRAZILIAN_STATES: frozenset[str] = frozenset(
    {
        "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA",
        "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO",
    }
)  # fmt: skip
