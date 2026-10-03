"""Regras das festas testadas direto no domínio, sem banco nem HTTP."""

import uuid
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from app.modules.catalog.pricing import PricingModel
from app.modules.parties.configuration import (
    InvalidItemConfigurationError,
    InvalidQuantityError,
)
from app.modules.parties.domain import (
    MAX_ITEMS_PER_PARTY,
    NO_QUOTE,
    CannotLockWithoutItemsError,
    Catalog,
    CatalogItem,
    CurrencyMismatchError,
    DesiredItem,
    DesiredParty,
    DuplicatePartyItemError,
    EventDateInPastError,
    EventDateRequiredError,
    EventDetailsRequiredError,
    GuestCountExceedsCapacityError,
    GuestCountRequiredError,
    HistoryActor,
    HistoryKind,
    InvalidItemRelationError,
    InvalidPartyTransitionError,
    InvalidQuoteResponseError,
    ItemNoLongerAvailableError,
    ItemRelation,
    ItemState,
    ListingNotAvailableError,
    ParentItemMissingError,
    PartyLockedError,
    PartyState,
    PartyStatus,
    QuoteRequestClosedError,
    QuoteStatus,
    RequiredItemMissingError,
    TooManyPartyItemsError,
    UnknownEventTypeError,
    VendorResponse,
    VenueAlreadySelectedError,
    apply_vendor_response,
    describe_transition,
    reconcile,
)

NOW = datetime(2026, 10, 3, 12, 0, tzinfo=UTC)
EVENT_DAY = NOW + timedelta(days=60)

VENDOR = uuid.UUID(int=900)
OTHER_VENDOR = uuid.UUID(int=901)

VENUE = uuid.UUID(int=1)
DJ = uuid.UUID(int=2)
OTHER_VENUE = uuid.UUID(int=3)
USD_ITEM = uuid.UUID(int=4)
BUFFET = uuid.UUID(int=5)
BAND = uuid.UUID(int=6)
FLOWERS = uuid.UUID(int=7)
CHAIRS = uuid.UUID(int=8)

OWN_BUFFET = uuid.UUID(int=101)
CLEANING = uuid.UUID(int=102)
OTHER_VENUE_BAR = uuid.UUID(int=103)

LISTINGS = {
    VENUE: CatalogItem(
        VENUE,
        "venue",
        "Salão Glamour",
        150_000,
        "BRL",
        "https://img/venue.jpg",
        capacity=120,
        vendor_id=VENDOR,
        required_offer_ids=frozenset({CLEANING}),
        partner_listing_ids=frozenset({BAND}),
    ),
    DJ: CatalogItem(DJ, "dj", "DJ Festa Boa", 80_000, "BRL", None, vendor_id=OTHER_VENDOR),
    OTHER_VENUE: CatalogItem(OTHER_VENUE, "venue", "Espaço Crystal", 200_000, "BRL", None),
    USD_ITEM: CatalogItem(USD_ITEM, "other", "Importado", 10_000, "USD", None),
    BUFFET: CatalogItem(
        BUFFET,
        "buffet",
        "Buffet Sabor",
        6_000,
        "BRL",
        None,
        pricing_model=PricingModel.PER_PERSON,
        minimum_cents=250_000,
    ),
    BAND: CatalogItem(
        BAND, "attraction", "Banda Festa Boa", 20_000, "BRL", None, PricingModel.PER_HOUR
    ),
    FLOWERS: CatalogItem(
        FLOWERS, "decoration", "Arte em Flores", 0, "BRL", None, PricingModel.ON_REQUEST
    ),
    CHAIRS: CatalogItem(CHAIRS, "other", "Cadeiras", 800, "BRL", None, PricingModel.PER_UNIT),
}
OFFERS = {
    OWN_BUFFET: CatalogItem(
        VENUE,
        "buffet",
        "Buffet do salão",
        4_500,
        "BRL",
        None,
        pricing_model=PricingModel.PER_PERSON,
        vendor_id=VENDOR,
        offer_id=OWN_BUFFET,
    ),
    CLEANING: CatalogItem(
        VENUE,
        "other",
        "Taxa de limpeza",
        15_000,
        "BRL",
        None,
        vendor_id=VENDOR,
        offer_id=CLEANING,
        required=True,
    ),
    OTHER_VENUE_BAR: CatalogItem(
        OTHER_VENUE, "buffet", "Bar do Crystal", 30_000, "BRL", None, offer_id=OTHER_VENUE_BAR
    ),
}
CATALOG = Catalog(
    listing=LISTINGS.get,
    offer=OFFERS.get,
    event_types=frozenset({"wedding", "debutante"}),
)
EMPTY_CATALOG = Catalog(listing=lambda _id: None)

FOUR_HOURS: dict[str, Any] = {"duration_hours": 4}


def item_id(n: int) -> uuid.UUID:
    return uuid.UUID(int=1000 + n)


def desired(
    status: PartyStatus = PartyStatus.PLANNING,
    *items: DesiredItem,
    title: str = "Aniversário da Ana",
    event_type: str | None = None,
    event_at: datetime | None = EVENT_DAY,
    guest_count: int | None = 80,
) -> DesiredParty:
    return DesiredParty(
        title=title,
        event_type=event_type,
        event_at=event_at,
        guest_count=guest_count,
        status=status,
        items=tuple(items),
    )


def want(
    n: int,
    listing_id: uuid.UUID | None,
    quantity: int = 1,
    *,
    offer: uuid.UUID | None = None,
    parent: int | None = None,
    **configuration: object,
) -> DesiredItem:
    return DesiredItem(
        id=item_id(n),
        listing_id=listing_id,
        offer_id=offer,
        parent_item_id=item_id(parent) if parent is not None else None,
        quantity=quantity,
        configuration=configuration,
    )


def dj(n: int = 1, **configuration: object) -> DesiredItem:
    """O DJ é contratado por um tempo: a duração é obrigatória."""
    return want(n, DJ, **(configuration or FOUR_HOURS))


def venue(n: int = 1, **configuration: object) -> DesiredItem:
    return want(n, VENUE, **(configuration or FOUR_HOURS))


def cleaning(n: int, *, parent: int) -> DesiredItem:
    return want(n, None, offer=CLEANING, parent=parent)


def save(
    current: PartyState | None,
    wanted: DesiredParty,
    *,
    catalog: Catalog = CATALOG,
    now: datetime = NOW,
) -> PartyState:
    return reconcile(current, wanted, catalog=catalog, now=now)


def planning_with_dj() -> PartyState:
    return save(None, desired(PartyStatus.PLANNING, dj()))


def locked_with_dj() -> PartyState:
    return save(planning_with_dj(), desired(PartyStatus.LOCKED, dj()))


def answer(
    state: PartyState,
    n: int,
    status: QuoteStatus = QuoteStatus.QUOTED,
    *,
    amount: int | None = 90_000,
    message: str | None = None,
) -> PartyState:
    """A festa depois que o fornecedor do item [n] respondeu."""
    if status is not QuoteStatus.QUOTED:
        amount = None
        message = message or "A data não está livre."
    new_state, _ = apply_vendor_response(
        state, item_id(n), VendorResponse(status, amount, message), now=NOW
    )
    return new_state


def quoted_with_dj() -> PartyState:
    return answer(locked_with_dj(), 1)


class TestCreation:
    @pytest.mark.parametrize("status", [PartyStatus.DRAFT, PartyStatus.PLANNING])
    def test_can_be_created_as_draft_or_planning(self, status: PartyStatus) -> None:
        state = save(None, desired(status))

        assert state.status is status
        assert state.items == ()
        assert state.estimate_cents == 0
        assert state.quote_round == 0

    @pytest.mark.parametrize(
        "status", [s for s in PartyStatus if s not in {PartyStatus.DRAFT, PartyStatus.PLANNING}]
    )
    def test_cannot_be_born_in_a_later_status(self, status: PartyStatus) -> None:
        with pytest.raises(InvalidPartyTransitionError):
            save(None, desired(status, dj()))

    def test_an_event_can_exist_without_items(self) -> None:
        state = save(None, desired(event_type="wedding", guest_count=120))

        assert state.event_type == "wedding"
        assert state.event_at == EVENT_DAY
        assert state.guest_count == 120


class TestEvent:
    def test_unknown_event_type_is_rejected(self) -> None:
        with pytest.raises(UnknownEventTypeError):
            save(None, desired(event_type="inexistente"))

    def test_an_event_type_already_stored_is_not_checked_again(self) -> None:
        # O tipo pode ter sido desativado depois: a festa continua editável.
        current = replace(planning_with_dj(), event_type="aposentado")

        state = save(current, desired(PartyStatus.PLANNING, dj(), event_type="aposentado"))

        assert state.event_type == "aposentado"

    def test_a_new_event_date_has_to_be_in_the_future(self) -> None:
        with pytest.raises(EventDateInPastError):
            save(None, desired(event_at=NOW - timedelta(days=1)))
        with pytest.raises(EventDateInPastError):
            save(None, desired(event_at=NOW))

    def test_a_party_whose_date_passed_can_still_be_edited(self) -> None:
        current = planning_with_dj()
        later = EVENT_DAY + timedelta(days=1)

        state = save(current, desired(PartyStatus.PLANNING, dj(), title="Outro nome"), now=later)

        assert state.title == "Outro nome"

    def test_guests_cannot_exceed_the_venue_capacity(self) -> None:
        # O Salão Glamour comporta 120 pessoas.
        with pytest.raises(GuestCountExceedsCapacityError) as error:
            save(None, desired(PartyStatus.PLANNING, venue(), cleaning(2, parent=1),
                               guest_count=121))  # fmt: skip
        assert "120" in error.value.message

    def test_raising_the_guests_later_is_checked_against_the_venue_too(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, venue(), cleaning(2, parent=1)))

        with pytest.raises(GuestCountExceedsCapacityError):
            save(
                current,
                desired(PartyStatus.PLANNING, venue(), cleaning(2, parent=1), guest_count=200),
            )

    def test_a_venue_needs_the_date_and_the_guests(self) -> None:
        for missing in ({"event_at": None}, {"guest_count": None}):
            with pytest.raises(EventDetailsRequiredError):
                save(
                    None,
                    desired(PartyStatus.PLANNING, venue(), cleaning(2, parent=1), **missing),  # type: ignore[arg-type]
                )

    def test_an_item_charged_per_person_needs_the_guests(self) -> None:
        with pytest.raises(GuestCountRequiredError):
            save(
                None,
                desired(
                    PartyStatus.PLANNING,
                    want(1, BUFFET, service_style="plated"),
                    guest_count=None,
                ),
            )

    def test_other_items_enter_without_event_details(self) -> None:
        state = save(None, desired(PartyStatus.PLANNING, dj(), event_at=None, guest_count=None))

        assert [item.name for item in state.items] == ["DJ Festa Boa"]


class TestItems:
    def test_new_item_copies_everything_from_the_catalog(self) -> None:
        state = save(None, desired(PartyStatus.PLANNING, venue(), cleaning(2, parent=1)))

        assert state.items[0] == ItemState(
            id=item_id(1),
            listing_id=VENUE,
            category="venue",
            name="Salão Glamour",
            unit_price_cents=150_000,
            currency="BRL",
            quantity=1,
            image_url="https://img/venue.jpg",
            vendor_id=VENDOR,
            pricing_model=PricingModel.FIXED,
            capacity=120,
            configuration={"duration_hours": 4},
        )

    def test_existing_item_keeps_its_price_even_if_the_catalog_changed(self) -> None:
        current = planning_with_dj()
        pricier = Catalog(
            listing=lambda listing_id: CatalogItem(
                listing_id, "dj", "DJ Festa Boa (novo)", 999_999, "BRL", None, PricingModel.PER_HOUR
            )
        )

        state = save(current, desired(PartyStatus.PLANNING, dj(duration_hours=6)), catalog=pricier)

        assert state.items[0].unit_price_cents == 80_000
        assert state.items[0].name == "DJ Festa Boa"
        assert state.items[0].pricing_model is PricingModel.FIXED
        assert state.items[0].configuration == {"duration_hours": 6}

    def test_existing_item_survives_the_listing_leaving_the_catalog(self) -> None:
        current = planning_with_dj()

        state = save(current, desired(PartyStatus.PLANNING, dj()), catalog=EMPTY_CATALOG)

        assert state.items == current.items

    def test_items_left_out_are_removed_and_order_follows_the_request(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, dj(1), want(2, CHAIRS)))

        state = save(current, desired(PartyStatus.PLANNING, want(2, CHAIRS)))

        assert [item.id for item in state.items] == [item_id(2)]

    def test_unknown_listing_is_rejected(self) -> None:
        with pytest.raises(ListingNotAvailableError):
            save(None, desired(PartyStatus.PLANNING, want(1, uuid.uuid4())))

    def test_a_new_item_needs_exactly_one_source(self) -> None:
        with pytest.raises(ListingNotAvailableError):
            save(None, desired(PartyStatus.PLANNING, want(1, None)))
        with pytest.raises(ListingNotAvailableError):
            save(None, desired(PartyStatus.PLANNING, want(1, VENUE, offer=CLEANING, parent=1)))

    def test_only_one_venue_per_party(self) -> None:
        with pytest.raises(VenueAlreadySelectedError):
            save(
                None,
                desired(
                    PartyStatus.PLANNING,
                    venue(1),
                    cleaning(2, parent=1),
                    want(3, OTHER_VENUE, **FOUR_HOURS),
                ),
            )

    def test_venue_can_be_swapped_in_one_step(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, venue(1), cleaning(2, parent=1)))

        state = save(current, desired(PartyStatus.PLANNING, want(3, OTHER_VENUE, **FOUR_HOURS)))

        assert [item.name for item in state.items] == ["Espaço Crystal"]

    def test_same_item_id_twice_is_rejected(self) -> None:
        with pytest.raises(DuplicatePartyItemError):
            save(None, desired(PartyStatus.PLANNING, dj(1), want(1, CHAIRS)))

    def test_same_listing_twice_is_rejected(self) -> None:
        with pytest.raises(DuplicatePartyItemError):
            save(None, desired(PartyStatus.PLANNING, dj(1), dj(2)))

    def test_all_items_must_share_the_currency(self) -> None:
        with pytest.raises(CurrencyMismatchError):
            save(None, desired(PartyStatus.PLANNING, dj(1), want(2, USD_ITEM)))

    def test_item_count_is_bounded(self) -> None:
        too_many = tuple(dj(n) for n in range(MAX_ITEMS_PER_PARTY + 1))

        with pytest.raises(TooManyPartyItemsError):
            save(None, desired(PartyStatus.PLANNING, *too_many))


class TestConfiguration:
    def test_each_category_asks_only_for_its_own_information(self) -> None:
        state = save(
            None,
            desired(
                PartyStatus.PLANNING,
                want(1, BUFFET, service_style="plated", menu="  Massas  ", notes=""),
                want(2, FLOWERS, 3, theme="Safari", environment="outdoor"),
            ),
        )

        # O texto sai limpo, e o que ficou vazio não é gravado.
        assert state.items[0].configuration == {"service_style": "plated", "menu": "Massas"}
        assert state.items[1].configuration == {"theme": "Safari", "environment": "outdoor"}
        assert state.items[1].quantity == 3

    @pytest.mark.parametrize(
        ("item", "field"),
        [
            (want(1, DJ), "duration_hours"),
            (want(1, DJ, duration_hours=0), "duration_hours"),
            (want(1, DJ, duration_hours=25), "duration_hours"),
            (want(1, DJ, duration_hours="quatro"), "duration_hours"),
            (want(1, DJ, duration_hours=True), "duration_hours"),
            (want(1, BUFFET), "service_style"),
            (want(1, BUFFET, service_style="rodizio"), "service_style"),
            (want(1, FLOWERS), "theme"),
            (want(1, FLOWERS, theme="x" * 81), "theme"),
            (want(1, DJ, duration_hours=4, theme="Safari"), "theme"),
        ],
        ids=[
            "duração faltando",
            "duração zero",
            "duração acima do dia",
            "duração em texto",
            "duração booleana",
            "tipo de buffet faltando",
            "tipo de buffet desconhecido",
            "tema faltando",
            "tema longo demais",
            "campo de outra categoria",
        ],
    )
    def test_rejects_an_invalid_configuration_naming_the_field(
        self, item: DesiredItem, field: str
    ) -> None:
        with pytest.raises(InvalidItemConfigurationError) as error:
            save(None, desired(PartyStatus.PLANNING, item))

        assert error.value.details is not None
        assert [problem["field"] for problem in error.value.details["fields"]] == [field]

    def test_an_item_charged_per_hour_needs_the_duration_whatever_the_category(self) -> None:
        per_hour = Catalog(
            listing=lambda listing_id: CatalogItem(
                listing_id, "other", "Fotógrafo", 30_000, "BRL", None, PricingModel.PER_HOUR
            )
        )

        with pytest.raises(InvalidItemConfigurationError):
            save(None, desired(PartyStatus.PLANNING, want(1, DJ)), catalog=per_hour)
        state = save(
            None, desired(PartyStatus.PLANNING, want(1, DJ, duration_hours=3)), catalog=per_hour
        )
        assert state.estimate_cents == 90_000

    @pytest.mark.parametrize("quantity", [2, 999])
    def test_quantity_only_where_it_makes_sense(self, quantity: int) -> None:
        # Cadeiras, sim; "dois DJs" ou "dois salões", não.
        state = save(None, desired(PartyStatus.PLANNING, want(1, CHAIRS, quantity)))
        assert state.items[0].quantity == quantity

        with pytest.raises(InvalidQuantityError):
            save(None, desired(PartyStatus.PLANNING, want(1, DJ, quantity, duration_hours=4)))

    @pytest.mark.parametrize("quantity", [0, 1000])
    def test_quantity_is_bounded(self, quantity: int) -> None:
        with pytest.raises(InvalidQuantityError):
            save(None, desired(PartyStatus.PLANNING, want(1, CHAIRS, quantity)))

    def test_an_item_stored_before_a_rule_existed_is_not_validated_again(self) -> None:
        # Um DJ gravado sem duração, de quando ela não era pedida.
        legacy = replace(planning_with_dj().items[0], configuration={})
        current = replace(planning_with_dj(), items=(legacy,))

        state = save(current, desired(PartyStatus.PLANNING, want(1, DJ), title="Outro nome"))

        assert state.items == (legacy,)
        # Mexeu no item, vale a regra de hoje.
        with pytest.raises(InvalidItemConfigurationError):
            save(current, desired(PartyStatus.PLANNING, want(1, DJ, notes="Chegar cedo")))


class TestEstimate:
    def test_each_item_is_estimated_by_how_it_charges(self) -> None:
        state = save(
            None,
            desired(
                PartyStatus.PLANNING,
                venue(1),  # fixo: R$ 1.500
                cleaning(2, parent=1),  # fixo: R$ 150
                want(3, BUFFET, service_style="plated"),  # 80 x R$ 60 = R$ 4.800
                want(4, BAND, parent=1, duration_hours=3),  # 3 x R$ 200 = R$ 600
                want(5, CHAIRS, 100),  # 100 x R$ 8 = R$ 800
            ),
        )

        assert [item.estimate_cents(state.guest_count) for item in state.items] == [
            150_000,
            15_000,
            480_000,
            60_000,
            80_000,
        ]
        assert state.estimate_cents == 785_000
        assert state.unpriced_items == 0

    def test_the_minimum_is_charged_when_the_guests_are_few(self) -> None:
        state = save(
            None,
            desired(PartyStatus.PLANNING, want(1, BUFFET, service_style="plated"), guest_count=10),
        )

        # 10 x R$ 60 = R$ 600, mas o buffet não sai por menos de R$ 2.500.
        assert state.estimate_cents == 250_000

    def test_an_item_on_request_stays_out_of_the_total_and_is_counted(self) -> None:
        state = save(None, desired(PartyStatus.PLANNING, dj(1), want(2, FLOWERS, theme="Safari")))

        assert state.items[1].estimate_cents(state.guest_count) is None
        assert state.estimate_cents == 80_000
        assert state.unpriced_items == 1

    def test_changing_the_guests_recalculates_what_is_charged_per_person(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, want(1, BUFFET, service_style="plated")))

        state = save(
            current,
            desired(PartyStatus.PLANNING, want(1, BUFFET, service_style="plated"), guest_count=100),
        )

        assert state.estimate_cents == 600_000


class TestRelations:
    def test_own_services_enter_linked_to_the_listing(self) -> None:
        state = save(
            None,
            desired(
                PartyStatus.PLANNING,
                venue(1),
                want(2, None, offer=OWN_BUFFET, parent=1),
                cleaning(3, parent=1),
            ),
        )

        buffet, fee = state.items[1], state.items[2]
        assert (buffet.relation, buffet.parent_item_id) == (ItemRelation.LINKED, item_id(1))
        assert (fee.relation, fee.parent_item_id) == (ItemRelation.REQUIRED, item_id(1))
        # Um serviço próprio não tem anúncio; o pedido vai para o dono do salão.
        assert (buffet.listing_id, buffet.offer_id, buffet.vendor_id) == (None, OWN_BUFFET, VENDOR)
        assert buffet.estimate_cents(state.guest_count) == 80 * 4_500

    def test_a_listing_cannot_enter_without_its_required_services(self) -> None:
        with pytest.raises(RequiredItemMissingError):
            save(None, desired(PartyStatus.PLANNING, venue(1)))
        with pytest.raises(RequiredItemMissingError):
            save(
                None,
                desired(PartyStatus.PLANNING, venue(1), want(2, None, offer=OWN_BUFFET, parent=1)),
            )

    def test_a_required_service_cannot_leave_alone(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, venue(1), cleaning(2, parent=1)))

        with pytest.raises(RequiredItemMissingError):
            save(current, desired(PartyStatus.PLANNING, venue(1)))

    def test_an_optional_service_can_leave_alone(self) -> None:
        current = save(
            None,
            desired(
                PartyStatus.PLANNING,
                venue(1),
                want(2, None, offer=OWN_BUFFET, parent=1),
                cleaning(3, parent=1),
            ),
        )

        state = save(current, desired(PartyStatus.PLANNING, venue(1), cleaning(3, parent=1)))

        assert [item.name for item in state.items] == ["Salão Glamour", "Taxa de limpeza"]

    def test_own_services_do_not_stay_without_the_listing(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, venue(1), cleaning(2, parent=1)))

        with pytest.raises(ParentItemMissingError):
            save(current, desired(PartyStatus.PLANNING, cleaning(2, parent=1)))

    def test_a_new_own_service_needs_its_listing_in_the_party(self) -> None:
        with pytest.raises(ParentItemMissingError):
            save(None, desired(PartyStatus.PLANNING, want(1, None, offer=OWN_BUFFET)))
        with pytest.raises(ParentItemMissingError):
            save(None, desired(PartyStatus.PLANNING, want(1, None, offer=OWN_BUFFET, parent=9)))

    def test_an_own_service_only_links_to_the_listing_it_belongs_to(self) -> None:
        with pytest.raises(InvalidItemRelationError):
            save(
                None,
                desired(
                    PartyStatus.PLANNING,
                    venue(1),
                    cleaning(2, parent=1),
                    # O bar é de outro salão.
                    want(3, None, offer=OTHER_VENUE_BAR, parent=1),
                ),
            )

    def test_a_partner_enters_as_recommended_by_the_listing(self) -> None:
        state = save(
            None,
            desired(
                PartyStatus.PLANNING,
                venue(1),
                cleaning(2, parent=1),
                want(3, BAND, parent=1, duration_hours=3),
            ),
        )

        band = state.items[2]
        assert (band.relation, band.parent_item_id) == (ItemRelation.RECOMMENDED, item_id(1))
        # É um anúncio à parte, com o próprio preço.
        assert band.listing_id == BAND

    def test_only_a_real_partner_can_be_declared_as_recommended(self) -> None:
        # A relação é conferida no catálogo, e não aceita porque o app disse.
        with pytest.raises(InvalidItemRelationError):
            save(
                None,
                desired(
                    PartyStatus.PLANNING,
                    venue(1),
                    cleaning(2, parent=1),
                    # O salão não recomenda este DJ.
                    want(3, DJ, parent=1, duration_hours=4),
                ),
            )
        with pytest.raises(InvalidItemRelationError):
            # A banda é parceira do salão, e não do DJ.
            save(
                None,
                desired(PartyStatus.PLANNING, dj(1), want(2, BAND, parent=1, duration_hours=3)),
            )

    def test_a_recommended_item_stays_when_who_recommended_it_leaves(self) -> None:
        current = save(
            None,
            desired(
                PartyStatus.PLANNING,
                venue(1),
                cleaning(2, parent=1),
                want(3, BAND, parent=1, duration_hours=3),
            ),
        )

        # Tanto faz se o app já soltou o item ou ainda aponta para o salão.
        for parent in (None, 1):
            state = save(
                current,
                desired(PartyStatus.PLANNING, want(3, BAND, parent=parent, duration_hours=3)),
            )

            assert len(state.items) == 1
            assert state.items[0].relation is ItemRelation.INDEPENDENT
            assert state.items[0].parent_item_id is None

    def test_the_relation_of_an_existing_item_cannot_be_rewritten(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, venue(1), cleaning(2, parent=1), dj(3)))

        with pytest.raises(InvalidItemRelationError):
            save(
                current,
                desired(
                    PartyStatus.PLANNING,
                    venue(1),
                    cleaning(2, parent=1),
                    want(3, DJ, parent=1, duration_hours=4),
                ),
            )
        with pytest.raises(InvalidItemRelationError):
            save(current, desired(PartyStatus.PLANNING, venue(1), cleaning(2, parent=3), dj(3)))

    def test_no_chains_of_linked_items(self) -> None:
        with pytest.raises(InvalidItemRelationError):
            save(
                None,
                desired(
                    PartyStatus.PLANNING,
                    venue(1),
                    cleaning(2, parent=1),
                    want(3, BAND, parent=2, duration_hours=3),
                ),
            )


class TestRequestingAQuote:
    def test_planning_with_items_can_request_a_quote(self) -> None:
        state = locked_with_dj()

        assert state.status is PartyStatus.LOCKED
        assert state.quote_round == 1
        assert state.items[0].quote.status is QuoteStatus.PENDING

    def test_cannot_request_without_items(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING))

        with pytest.raises(CannotLockWithoutItemsError):
            save(current, desired(PartyStatus.LOCKED))

    def test_draft_cannot_jump_to_a_request(self) -> None:
        current = save(None, desired(PartyStatus.DRAFT, dj()))

        with pytest.raises(InvalidPartyTransitionError):
            save(current, desired(PartyStatus.LOCKED, dj()))

    def test_needs_the_date_and_the_guests(self) -> None:
        current = save(None, desired(PartyStatus.PLANNING, dj(), event_at=None, guest_count=None))

        with pytest.raises(EventDateRequiredError):
            save(current, desired(PartyStatus.LOCKED, dj(), event_at=None, guest_count=None))
        with pytest.raises(GuestCountRequiredError):
            save(current, desired(PartyStatus.LOCKED, dj(), guest_count=None))

    def test_the_date_has_to_be_still_ahead(self) -> None:
        # A data era futura quando foi informada, e passou.
        with pytest.raises(EventDateInPastError):
            save(
                planning_with_dj(),
                desired(PartyStatus.LOCKED, dj()),
                now=EVENT_DAY + timedelta(minutes=1),
            )

    def test_every_item_has_to_be_still_available(self) -> None:
        with pytest.raises(ItemNoLongerAvailableError) as error:
            save(planning_with_dj(), desired(PartyStatus.LOCKED, dj()), catalog=EMPTY_CATALOG)

        assert "DJ Festa Boa" in error.value.message

    def test_items_can_change_in_the_same_step_that_requests(self) -> None:
        state = save(planning_with_dj(), desired(PartyStatus.LOCKED, dj(), want(2, CHAIRS, 10)))

        assert state.status is PartyStatus.LOCKED
        assert state.estimate_cents == 80_000 + 10 * 800
        assert {item.quote.status for item in state.items} == {QuoteStatus.PENDING}

    @pytest.mark.parametrize(
        "change",
        [
            {"title": "Outro nome"},
            {"guest_count": 50},
            {"event_at": EVENT_DAY + timedelta(days=1)},
            {"event_type": "wedding"},
        ],
    )
    def test_a_requested_party_rejects_content_changes(self, change: dict[str, object]) -> None:
        with pytest.raises(PartyLockedError):
            save(locked_with_dj(), desired(PartyStatus.LOCKED, dj(), **change))  # type: ignore[arg-type]

    @pytest.mark.parametrize(
        "items",
        [(), (dj(duration_hours=5),), (dj(), want(2, CHAIRS)), (dj(notes="Chegar cedo"),)],
        ids=["removendo", "mudando a duração", "adicionando", "mudando as observações"],
    )
    def test_a_requested_party_rejects_item_changes(self, items: tuple[DesiredItem, ...]) -> None:
        with pytest.raises(PartyLockedError):
            save(locked_with_dj(), desired(PartyStatus.LOCKED, *items))

    @pytest.mark.parametrize("build", [locked_with_dj, quoted_with_dj])
    def test_the_frozen_content_holds_in_every_requested_status(self, build) -> None:
        state = build()

        with pytest.raises(PartyLockedError):
            save(state, desired(state.status, dj(), title="Outro nome"))

    def test_the_client_can_never_set_what_only_a_vendor_answer_sets(self) -> None:
        for target in (PartyStatus.QUOTED, PartyStatus.EDIT_REQUESTED, PartyStatus.CONFIRMED):
            with pytest.raises(InvalidPartyTransitionError):
                save(locked_with_dj(), desired(target, dj()))


class TestVendorResponse:
    def test_a_quote_on_the_only_item_makes_the_party_quoted(self) -> None:
        state, entry = apply_vendor_response(
            locked_with_dj(),
            item_id(1),
            VendorResponse(QuoteStatus.QUOTED, 95_000, "  Inclui equipamento.  "),
            now=NOW,
        )

        quote = state.items[0].quote
        assert state.status is PartyStatus.QUOTED
        assert (quote.status, quote.amount_cents) == (QuoteStatus.QUOTED, 95_000)
        assert (quote.message, quote.responded_at) == ("Inclui equipamento.", NOW)
        assert state.quoted_cents == 95_000
        assert (entry.kind, entry.actor) == (HistoryKind.VENDOR_QUOTED, HistoryActor.VENDOR)
        assert (entry.item_name, entry.amount_cents) == ("DJ Festa Boa", 95_000)
        assert entry.round == 1

    def test_the_party_waits_until_every_vendor_answers(self) -> None:
        requested = save(planning_with_dj(), desired(PartyStatus.LOCKED, dj(), want(2, CHAIRS, 10)))

        partly = answer(requested, 1)
        assert partly.status is PartyStatus.LOCKED
        assert partly.quoted_cents == 90_000

        assert answer(partly, 2, amount=7_000).status is PartyStatus.QUOTED

    @pytest.mark.parametrize(
        ("status", "kind"),
        [
            (QuoteStatus.CHANGES_REQUESTED, HistoryKind.VENDOR_REQUESTED_CHANGES),
            (QuoteStatus.DECLINED, HistoryKind.VENDOR_DECLINED),
        ],
    )
    def test_a_change_request_or_a_refusal_asks_the_client_to_edit(
        self, status: QuoteStatus, kind: HistoryKind
    ) -> None:
        state, entry = apply_vendor_response(
            locked_with_dj(),
            item_id(1),
            VendorResponse(status, message="Nesse dia só atendo até as 22h."),
            now=NOW,
        )

        assert state.status is PartyStatus.EDIT_REQUESTED
        assert state.items[0].quote.status is status
        assert state.items[0].quote.amount_cents is None
        assert (entry.kind, entry.message) == (kind, "Nesse dia só atendo até as 22h.")

    def test_one_change_request_outweighs_the_quotes_already_given(self) -> None:
        requested = save(planning_with_dj(), desired(PartyStatus.LOCKED, dj(), want(2, CHAIRS, 10)))

        state = answer(answer(requested, 1), 2, QuoteStatus.CHANGES_REQUESTED)

        assert state.status is PartyStatus.EDIT_REQUESTED

    def test_a_vendor_can_correct_the_answer_until_the_client_accepts(self) -> None:
        state = answer(quoted_with_dj(), 1, amount=70_000)
        assert (state.status, state.quoted_cents) == (PartyStatus.QUOTED, 70_000)

        state = answer(state, 1, QuoteStatus.DECLINED)
        assert state.status is PartyStatus.EDIT_REQUESTED

        state = answer(state, 1, amount=85_000)
        assert (state.status, state.quoted_cents) == (PartyStatus.QUOTED, 85_000)

    @pytest.mark.parametrize(
        "response",
        [
            VendorResponse(QuoteStatus.QUOTED),
            VendorResponse(QuoteStatus.QUOTED, -1),
            VendorResponse(QuoteStatus.QUOTED, 1_000_000_001),
            VendorResponse(QuoteStatus.QUOTED, 100, "x" * 501),
            VendorResponse(QuoteStatus.CHANGES_REQUESTED),
            VendorResponse(QuoteStatus.CHANGES_REQUESTED, message="  ok "),
            VendorResponse(QuoteStatus.DECLINED, message=""),
            VendorResponse(QuoteStatus.PENDING),
            VendorResponse(QuoteStatus.NONE),
        ],
        ids=[
            "orçamento sem valor",
            "valor negativo",
            "valor acima do teto",
            "mensagem longa demais",
            "pedido de alteração sem motivo",
            "motivo curto demais",
            "recusa sem motivo",
            "resposta que não é resposta",
            "resposta vazia",
        ],
    )
    def test_rejects_an_invalid_answer(self, response: VendorResponse) -> None:
        with pytest.raises(InvalidQuoteResponseError):
            apply_vendor_response(locked_with_dj(), item_id(1), response, now=NOW)

    def test_a_quote_of_zero_is_a_valid_answer(self) -> None:
        # Uma cortesia: o fornecedor não cobra por aquele item.
        assert answer(locked_with_dj(), 1, amount=0).quoted_cents == 0

    @pytest.mark.parametrize(
        "status",
        [PartyStatus.PLANNING, PartyStatus.CONFIRMED, PartyStatus.CANCELLED, PartyStatus.PAID],
    )
    def test_no_answer_when_the_request_is_not_open(self, status: PartyStatus) -> None:
        closed = replace(locked_with_dj(), status=status)

        with pytest.raises(QuoteRequestClosedError):
            apply_vendor_response(
                closed, item_id(1), VendorResponse(QuoteStatus.QUOTED, 100), now=NOW
            )

    def test_no_answer_for_an_item_that_is_not_in_the_party(self) -> None:
        with pytest.raises(QuoteRequestClosedError):
            apply_vendor_response(
                locked_with_dj(), item_id(9), VendorResponse(QuoteStatus.QUOTED, 100), now=NOW
            )


class TestEditingAfterTheRequest:
    def test_reopening_returns_to_planning_without_touching_content(self) -> None:
        requested = locked_with_dj()

        state = save(requested, desired(PartyStatus.PLANNING, dj()))

        assert state.status is PartyStatus.PLANNING
        assert state.quote_round == 1
        # O pedido foi retirado: quem não tinha respondido não responde mais.
        assert state.items == (replace(requested.items[0], quote=NO_QUOTE),)

    def test_cannot_reopen_and_edit_in_the_same_step(self) -> None:
        with pytest.raises(PartyLockedError):
            save(locked_with_dj(), desired(PartyStatus.PLANNING, dj(duration_hours=5)))

    def test_what_the_vendor_answered_stays_visible_while_the_client_edits(self) -> None:
        asked = answer(locked_with_dj(), 1, QuoteStatus.CHANGES_REQUESTED, message="Só até as 22h.")

        state = save(asked, desired(PartyStatus.PLANNING, dj()))

        assert state.status is PartyStatus.PLANNING
        assert state.items[0].quote.status is QuoteStatus.CHANGES_REQUESTED
        assert state.items[0].quote.message == "Só até as 22h."

    def test_resending_starts_a_new_round_and_asks_again_who_did_not_quote(self) -> None:
        asked = answer(locked_with_dj(), 1, QuoteStatus.CHANGES_REQUESTED)
        editing = save(asked, desired(PartyStatus.PLANNING, dj()))
        edited = save(editing, desired(PartyStatus.PLANNING, dj(duration_hours=3)))

        state = save(edited, desired(PartyStatus.LOCKED, dj(duration_hours=3)))

        assert (state.status, state.quote_round) == (PartyStatus.LOCKED, 2)
        assert state.items[0].quote == replace(NO_QUOTE, status=QuoteStatus.PENDING)

    def test_a_quote_survives_when_nothing_changed_for_that_vendor(self) -> None:
        requested = save(planning_with_dj(), desired(PartyStatus.LOCKED, dj(), want(2, CHAIRS, 10)))
        answered = answer(answer(requested, 1), 2, QuoteStatus.CHANGES_REQUESTED)
        editing = save(answered, desired(PartyStatus.PLANNING, dj(), want(2, CHAIRS, 10)))

        # Só as cadeiras mudam: o DJ já deu o preço e não precisa responder de novo.
        state = save(editing, desired(PartyStatus.LOCKED, dj(), want(2, CHAIRS, 20)))

        assert state.status is PartyStatus.LOCKED
        assert state.items[0].quote.status is QuoteStatus.QUOTED
        assert state.items[0].quote.amount_cents == 90_000
        assert state.items[1].quote.status is QuoteStatus.PENDING

    def test_changing_the_item_discards_the_quote_given_for_it(self) -> None:
        editing = save(quoted_with_dj(), desired(PartyStatus.PLANNING, dj()))

        state = save(editing, desired(PartyStatus.PLANNING, dj(duration_hours=6)))

        assert state.items[0].quote == NO_QUOTE
        assert state.quoted_cents is None

    @pytest.mark.parametrize(
        "change",
        [
            {"guest_count": 50},
            {"event_at": EVENT_DAY + timedelta(days=1)},
            {"event_type": "wedding"},
        ],
    )
    def test_changing_the_event_discards_every_quote(self, change: dict[str, object]) -> None:
        editing = save(quoted_with_dj(), desired(PartyStatus.PLANNING, dj()))

        state = save(editing, desired(PartyStatus.PLANNING, dj(), **change))  # type: ignore[arg-type]

        assert state.items[0].quote == NO_QUOTE

    def test_renaming_the_party_keeps_the_quotes(self) -> None:
        # O fornecedor nem vê o nome da festa.
        editing = save(quoted_with_dj(), desired(PartyStatus.PLANNING, dj()))

        state = save(editing, desired(PartyStatus.PLANNING, dj(), title="Outro nome"))

        assert state.items[0].quote.status is QuoteStatus.QUOTED

    def test_resending_with_everything_already_quoted_is_quoted_at_once(self) -> None:
        editing = save(quoted_with_dj(), desired(PartyStatus.PLANNING, dj()))

        state = save(editing, desired(PartyStatus.LOCKED, dj(), title="Outro nome"))

        assert (state.status, state.quote_round) == (PartyStatus.QUOTED, 2)


class TestConfirmationCancellationAndPayment:
    def test_a_quoted_party_can_be_confirmed(self) -> None:
        state = save(quoted_with_dj(), desired(PartyStatus.CONFIRMED, dj()))

        assert state.status is PartyStatus.CONFIRMED
        assert state.items[0].quote.amount_cents == 90_000

    @pytest.mark.parametrize(
        "build",
        [
            planning_with_dj,
            locked_with_dj,
            lambda: answer(locked_with_dj(), 1, QuoteStatus.DECLINED),
        ],
        ids=["planejamento", "esperando resposta", "edição solicitada"],
    )
    def test_only_a_fully_quoted_party_can_be_confirmed(self, build) -> None:
        with pytest.raises(InvalidPartyTransitionError):
            save(build(), desired(PartyStatus.CONFIRMED, dj()))

    def test_a_confirmed_party_no_longer_takes_vendor_answers_but_can_be_reopened(self) -> None:
        confirmed = save(quoted_with_dj(), desired(PartyStatus.CONFIRMED, dj()))

        with pytest.raises(QuoteRequestClosedError):
            answer(confirmed, 1, amount=1)
        assert save(confirmed, desired(PartyStatus.PLANNING, dj())).status is PartyStatus.PLANNING

    @pytest.mark.parametrize(
        "build",
        [
            planning_with_dj,
            locked_with_dj,
            quoted_with_dj,
            lambda: save(quoted_with_dj(), desired(PartyStatus.CONFIRMED, dj())),
        ],
        ids=["planejamento", "solicitado", "recebido", "confirmada"],
    )
    def test_everything_but_paid_can_be_cancelled(self, build) -> None:
        state = save(build(), desired(PartyStatus.CANCELLED, dj()))

        assert state.status is PartyStatus.CANCELLED

    def test_cancelled_party_is_frozen(self) -> None:
        cancelled = save(planning_with_dj(), desired(PartyStatus.CANCELLED, dj()))

        with pytest.raises(InvalidPartyTransitionError):
            save(cancelled, desired(PartyStatus.PLANNING, dj()))
        with pytest.raises(InvalidPartyTransitionError):
            save(cancelled, desired(PartyStatus.CANCELLED, dj(), title="Outro nome"))

    @pytest.mark.parametrize(
        "build",
        [lambda: None, planning_with_dj, locked_with_dj, quoted_with_dj],
        ids=["nova", "planejamento", "solicitado", "recebido"],
    )
    def test_the_client_can_never_mark_a_party_as_paid(self, build) -> None:
        with pytest.raises(InvalidPartyTransitionError):
            save(build(), desired(PartyStatus.PAID, dj()))

    def test_paid_party_cannot_be_cancelled_or_edited(self) -> None:
        paid = replace(locked_with_dj(), status=PartyStatus.PAID)

        with pytest.raises(InvalidPartyTransitionError):
            save(paid, desired(PartyStatus.CANCELLED, dj()))
        with pytest.raises(InvalidPartyTransitionError):
            save(paid, desired(PartyStatus.PAID, dj(duration_hours=5)))


class TestHistory:
    def test_requesting_a_quote_is_recorded_with_the_estimate(self) -> None:
        current = planning_with_dj()

        entry = describe_transition(current, locked_with_dj())

        assert entry is not None
        assert (entry.kind, entry.actor) == (HistoryKind.QUOTE_REQUESTED, HistoryActor.CLIENT)
        assert (entry.round, entry.amount_cents) == (1, 80_000)

    def test_reopening_confirming_and_cancelling_are_recorded(self) -> None:
        quoted = quoted_with_dj()
        reopened = save(quoted, desired(PartyStatus.PLANNING, dj()))
        confirmed = save(quoted, desired(PartyStatus.CONFIRMED, dj()))
        cancelled = save(quoted, desired(PartyStatus.CANCELLED, dj()))

        kinds = [describe_transition(quoted, state) for state in (reopened, confirmed, cancelled)]

        assert [entry.kind for entry in kinds if entry] == [
            HistoryKind.REOPENED,
            HistoryKind.CONFIRMED,
            HistoryKind.CANCELLED,
        ]
        # O que foi aceito fica registrado com o valor.
        assert kinds[1] is not None
        assert kinds[1].amount_cents == 90_000

    def test_ordinary_edits_are_not_events(self) -> None:
        current = planning_with_dj()
        renamed = save(current, desired(PartyStatus.PLANNING, dj(), title="Outro nome"))

        assert describe_transition(None, current) is None
        assert describe_transition(current, renamed) is None

    def test_a_second_request_belongs_to_the_second_round(self) -> None:
        editing = save(quoted_with_dj(), desired(PartyStatus.PLANNING, dj()))
        resent = save(editing, desired(PartyStatus.LOCKED, dj()))

        entry = describe_transition(editing, resent)

        assert entry is not None
        assert (entry.kind, entry.round) == (HistoryKind.QUOTE_REQUESTED, 2)


def test_repeating_the_same_request_is_a_no_op() -> None:
    current = planning_with_dj()

    assert save(current, desired(PartyStatus.PLANNING, dj())) == current
    locked = locked_with_dj()
    assert save(locked, desired(PartyStatus.LOCKED, dj())) == locked
