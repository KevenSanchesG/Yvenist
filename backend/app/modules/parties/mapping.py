"""Tradução entre as tabelas da festa e o estado que as regras entendem."""

from app.core.database import utcnow
from app.modules.parties.domain import HistoryEntry, ItemState, PartyState, Quote
from app.modules.parties.models import Party, PartyEvent, PartyItem


def item_state(item: PartyItem) -> ItemState:
    return ItemState(
        id=item.id,
        listing_id=item.listing_id,
        offer_id=item.offer_id,
        vendor_id=item.vendor_id,
        parent_item_id=item.parent_item_id,
        relation=item.relation,
        category=item.category,
        name=item.name,
        pricing_model=item.pricing_model,
        unit_price_cents=item.unit_price_cents,
        minimum_cents=item.minimum_cents,
        currency=item.currency,
        quantity=item.quantity,
        configuration=dict(item.configuration),
        capacity=item.capacity,
        image_url=item.image_url,
        quote=Quote(
            status=item.quote_status,
            amount_cents=item.quoted_cents,
            message=item.quote_message,
            responded_at=item.quote_responded_at,
        ),
    )


def to_state(party: Party) -> PartyState:
    """A festa gravada, no formato das regras. Exige os itens já carregados."""
    return PartyState(
        title=party.title,
        event_type=party.event_type,
        event_at=party.event_at,
        guest_count=party.guest_count,
        status=party.status,
        quote_round=party.quote_round,
        items=tuple(item_state(item) for item in party.items),
    )


def write_quote(item: PartyItem, quote: Quote) -> None:
    item.quote_status = quote.status
    item.quoted_cents = quote.amount_cents
    item.quote_message = quote.message
    item.quote_responded_at = quote.responded_at


def record(party: Party, entry: HistoryEntry) -> None:
    """Acrescenta um acontecimento ao histórico. Exige ``party.events`` carregado."""
    party.events.append(
        PartyEvent(
            sequence=len(party.events) + 1,
            kind=entry.kind,
            actor=entry.actor,
            quote_round=entry.round,
            item_id=entry.item_id,
            item_name=entry.item_name,
            message=entry.message,
            amount_cents=entry.amount_cents,
            created_at=utcnow(),
        )
    )
