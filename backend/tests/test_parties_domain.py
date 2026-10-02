"""Regras das festas testadas direto no domínio, sem banco nem HTTP."""

import uuid
from datetime import UTC, datetime

import pytest

from app.modules.parties.domain import (
    MAX_ITEMS_PER_PARTY,
    CannotLockWithoutItemsError,
    CatalogItem,
    CurrencyMismatchError,
    DesiredItem,
    DesiredParty,
    DuplicatePartyItemError,
    InvalidPartyTransitionError,
    ItemState,
    ListingNotAvailableError,
    PartyLockedError,
    PartyState,
    PartyStatus,
    TooManyPartyItemsError,
    VenueAlreadySelectedError,
    reconcile,
)

VENUE = uuid.UUID(int=1)
DJ = uuid.UUID(int=2)
OTHER_VENUE = uuid.UUID(int=3)
USD_ITEM = uuid.UUID(int=4)

CATALOG = {
    VENUE: CatalogItem(VENUE, "venue", "Salão Glamour", 150_000, "BRL", "https://img/venue.jpg"),
    DJ: CatalogItem(DJ, "dj", "DJ Festa Boa", 80_000, "BRL", None),
    OTHER_VENUE: CatalogItem(OTHER_VENUE, "venue", "Espaço Crystal", 200_000, "BRL", None),
    USD_ITEM: CatalogItem(USD_ITEM, "other", "Importado", 10_000, "USD", None),
}


def lookup(listing_id: uuid.UUID) -> CatalogItem | None:
    return CATALOG.get(listing_id)


def item_id(n: int) -> uuid.UUID:
    return uuid.UUID(int=1000 + n)


def desired(
    status: PartyStatus = PartyStatus.PLANNING,
    *items: DesiredItem,
    title: str = "Aniversário da Ana",
    event_at: datetime | None = None,
    guest_count: int | None = None,
) -> DesiredParty:
    return DesiredParty(
        title=title,
        event_at=event_at,
        guest_count=guest_count,
        status=status,
        items=tuple(items),
    )


def want(n: int, listing_id: uuid.UUID | None, quantity: int = 1) -> DesiredItem:
    return DesiredItem(id=item_id(n), listing_id=listing_id, quantity=quantity)


def planning_with_dj() -> PartyState:
    return reconcile(None, desired(PartyStatus.PLANNING, want(1, DJ)), lookup=lookup)


def locked_with_dj() -> PartyState:
    return reconcile(planning_with_dj(), desired(PartyStatus.LOCKED, want(1, DJ)), lookup=lookup)


class TestCreation:
    @pytest.mark.parametrize("status", [PartyStatus.DRAFT, PartyStatus.PLANNING])
    def test_can_be_created_as_draft_or_planning(self, status: PartyStatus) -> None:
        state = reconcile(None, desired(status), lookup=lookup)

        assert state.status is status
        assert state.items == ()
        assert state.total_cents == 0

    @pytest.mark.parametrize(
        "status", [PartyStatus.LOCKED, PartyStatus.PAID, PartyStatus.CANCELLED]
    )
    def test_cannot_be_born_in_a_later_status(self, status: PartyStatus) -> None:
        with pytest.raises(InvalidPartyTransitionError):
            reconcile(None, desired(status, want(1, DJ)), lookup=lookup)


class TestItems:
    def test_new_item_copies_name_category_and_price_from_the_catalog(self) -> None:
        state = reconcile(None, desired(PartyStatus.PLANNING, want(1, VENUE, 2)), lookup=lookup)

        assert state.items == (
            ItemState(
                id=item_id(1),
                listing_id=VENUE,
                category="venue",
                name="Salão Glamour",
                unit_price_cents=150_000,
                currency="BRL",
                quantity=2,
                image_url="https://img/venue.jpg",
            ),
        )
        assert state.total_cents == 300_000

    def test_existing_item_keeps_its_price_even_if_the_catalog_changed(self) -> None:
        current = planning_with_dj()

        def pricier_lookup(listing_id: uuid.UUID) -> CatalogItem | None:
            return CatalogItem(listing_id, "dj", "DJ Festa Boa (novo)", 999_999, "BRL", None)

        state = reconcile(
            current, desired(PartyStatus.PLANNING, want(1, DJ, 3)), lookup=pricier_lookup
        )

        assert state.items[0].unit_price_cents == 80_000
        assert state.items[0].name == "DJ Festa Boa"
        assert state.items[0].quantity == 3

    def test_existing_item_survives_the_listing_leaving_the_catalog(self) -> None:
        current = planning_with_dj()

        state = reconcile(
            current, desired(PartyStatus.PLANNING, want(1, DJ)), lookup=lambda _id: None
        )

        assert state.items == current.items

    def test_items_left_out_are_removed_and_order_follows_the_request(self) -> None:
        current = reconcile(
            None, desired(PartyStatus.PLANNING, want(1, DJ), want(2, VENUE)), lookup=lookup
        )

        state = reconcile(current, desired(PartyStatus.PLANNING, want(2, VENUE)), lookup=lookup)

        assert [item.id for item in state.items] == [item_id(2)]

    def test_unknown_listing_is_rejected(self) -> None:
        with pytest.raises(ListingNotAvailableError):
            reconcile(None, desired(PartyStatus.PLANNING, want(1, uuid.uuid4())), lookup=lookup)

    def test_new_item_without_listing_is_rejected(self) -> None:
        with pytest.raises(ListingNotAvailableError):
            reconcile(None, desired(PartyStatus.PLANNING, want(1, None)), lookup=lookup)

    def test_only_one_venue_per_party(self) -> None:
        with pytest.raises(VenueAlreadySelectedError):
            reconcile(
                None,
                desired(PartyStatus.PLANNING, want(1, VENUE), want(2, OTHER_VENUE)),
                lookup=lookup,
            )

    def test_venue_can_be_swapped_in_one_step(self) -> None:
        current = reconcile(None, desired(PartyStatus.PLANNING, want(1, VENUE)), lookup=lookup)

        state = reconcile(
            current, desired(PartyStatus.PLANNING, want(2, OTHER_VENUE)), lookup=lookup
        )

        assert [item.name for item in state.items] == ["Espaço Crystal"]

    def test_same_item_id_twice_is_rejected(self) -> None:
        with pytest.raises(DuplicatePartyItemError):
            reconcile(
                None, desired(PartyStatus.PLANNING, want(1, DJ), want(1, VENUE)), lookup=lookup
            )

    def test_same_listing_twice_is_rejected(self) -> None:
        with pytest.raises(DuplicatePartyItemError):
            reconcile(None, desired(PartyStatus.PLANNING, want(1, DJ), want(2, DJ)), lookup=lookup)

    def test_all_items_must_share_the_currency(self) -> None:
        with pytest.raises(CurrencyMismatchError):
            reconcile(
                None, desired(PartyStatus.PLANNING, want(1, DJ), want(2, USD_ITEM)), lookup=lookup
            )

    def test_item_count_is_bounded(self) -> None:
        too_many = tuple(want(n, DJ) for n in range(MAX_ITEMS_PER_PARTY + 1))

        with pytest.raises(TooManyPartyItemsError):
            reconcile(None, desired(PartyStatus.PLANNING, *too_many), lookup=lookup)


class TestLocking:
    def test_planning_with_items_can_be_locked(self) -> None:
        assert locked_with_dj().status is PartyStatus.LOCKED

    def test_cannot_lock_without_items(self) -> None:
        current = reconcile(None, desired(PartyStatus.PLANNING), lookup=lookup)

        with pytest.raises(CannotLockWithoutItemsError):
            reconcile(current, desired(PartyStatus.LOCKED), lookup=lookup)

    def test_draft_cannot_jump_to_locked(self) -> None:
        current = reconcile(None, desired(PartyStatus.DRAFT, want(1, DJ)), lookup=lookup)

        with pytest.raises(InvalidPartyTransitionError):
            reconcile(current, desired(PartyStatus.LOCKED, want(1, DJ)), lookup=lookup)

    def test_items_can_change_in_the_same_step_that_locks(self) -> None:
        state = reconcile(
            planning_with_dj(),
            desired(PartyStatus.LOCKED, want(1, DJ, 2), want(2, VENUE)),
            lookup=lookup,
        )

        assert state.status is PartyStatus.LOCKED
        assert state.total_cents == 2 * 80_000 + 150_000

    @pytest.mark.parametrize(
        "change",
        [
            {"title": "Outro nome"},
            {"guest_count": 50},
            {"event_at": datetime(2027, 1, 1, tzinfo=UTC)},
        ],
    )
    def test_locked_party_rejects_content_changes(self, change: dict[str, object]) -> None:
        with pytest.raises(PartyLockedError):
            reconcile(
                locked_with_dj(),
                desired(PartyStatus.LOCKED, want(1, DJ), **change),  # type: ignore[arg-type]
                lookup=lookup,
            )

    @pytest.mark.parametrize(
        "items",
        [(), (want(1, DJ, 5),), (want(1, DJ), want(2, VENUE))],
        ids=["removendo", "mudando quantidade", "adicionando"],
    )
    def test_locked_party_rejects_item_changes(self, items: tuple[DesiredItem, ...]) -> None:
        with pytest.raises(PartyLockedError):
            reconcile(locked_with_dj(), desired(PartyStatus.LOCKED, *items), lookup=lookup)

    def test_unlocking_returns_to_planning_without_touching_content(self) -> None:
        locked = locked_with_dj()

        state = reconcile(locked, desired(PartyStatus.PLANNING, want(1, DJ)), lookup=lookup)

        assert state.status is PartyStatus.PLANNING
        assert state.items == locked.items

    def test_cannot_unlock_and_edit_in_the_same_step(self) -> None:
        with pytest.raises(PartyLockedError):
            reconcile(
                locked_with_dj(), desired(PartyStatus.PLANNING, want(1, DJ, 2)), lookup=lookup
            )


class TestCancellationAndPayment:
    @pytest.mark.parametrize("build", [planning_with_dj, locked_with_dj])
    def test_planning_and_locked_can_be_cancelled(self, build) -> None:
        state = reconcile(build(), desired(PartyStatus.CANCELLED, want(1, DJ)), lookup=lookup)

        assert state.status is PartyStatus.CANCELLED

    def test_cancelled_party_is_frozen(self) -> None:
        cancelled = reconcile(
            planning_with_dj(), desired(PartyStatus.CANCELLED, want(1, DJ)), lookup=lookup
        )

        with pytest.raises(InvalidPartyTransitionError):
            reconcile(cancelled, desired(PartyStatus.PLANNING, want(1, DJ)), lookup=lookup)
        with pytest.raises(InvalidPartyTransitionError):
            reconcile(
                cancelled,
                desired(PartyStatus.CANCELLED, want(1, DJ), title="Outro nome"),
                lookup=lookup,
            )

    @pytest.mark.parametrize(
        "build",
        [lambda: None, planning_with_dj, locked_with_dj],
        ids=["nova", "planning", "locked"],
    )
    def test_the_client_can_never_mark_a_party_as_paid(self, build) -> None:
        with pytest.raises(InvalidPartyTransitionError):
            reconcile(build(), desired(PartyStatus.PAID, want(1, DJ)), lookup=lookup)

    def test_paid_party_cannot_be_cancelled_or_edited(self) -> None:
        paid = PartyState(
            title="Aniversário da Ana",
            event_at=None,
            guest_count=None,
            status=PartyStatus.PAID,
            items=locked_with_dj().items,
        )

        with pytest.raises(InvalidPartyTransitionError):
            reconcile(paid, desired(PartyStatus.CANCELLED, want(1, DJ)), lookup=lookup)
        with pytest.raises(InvalidPartyTransitionError):
            reconcile(paid, desired(PartyStatus.PAID, want(1, DJ, 2)), lookup=lookup)


def test_repeating_the_same_request_is_a_no_op() -> None:
    current = planning_with_dj()

    assert reconcile(current, desired(PartyStatus.PLANNING, want(1, DJ)), lookup=lookup) == current
