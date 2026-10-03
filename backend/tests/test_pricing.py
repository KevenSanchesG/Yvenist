"""A estimativa de preço, testada direto: sem banco nem HTTP."""

import pytest

from app.modules.catalog.pricing import PricingModel, estimate_cents, public_price


def estimate(
    model: PricingModel,
    price: int | None = 10_000,
    *,
    minimum: int | None = None,
    guests: int | None = 50,
    hours: int | None = 4,
    quantity: int = 1,
) -> int | None:
    return estimate_cents(
        model, price, minimum_cents=minimum, guests=guests, hours=hours, quantity=quantity
    )


class TestEstimate:
    def test_fixed_is_the_price_whatever_the_configuration(self) -> None:
        assert estimate(PricingModel.FIXED, guests=200, hours=12, quantity=9) == 10_000

    def test_per_unit_multiplies_by_the_quantity(self) -> None:
        assert estimate(PricingModel.PER_UNIT, quantity=3) == 30_000

    def test_per_person_multiplies_by_the_guests(self) -> None:
        assert estimate(PricingModel.PER_PERSON, guests=80) == 800_000

    def test_per_hour_multiplies_by_the_hours(self) -> None:
        assert estimate(PricingModel.PER_HOUR, hours=5) == 50_000

    def test_per_hour_and_per_person_also_count_the_quantity(self) -> None:
        # Dois seguranças por cinco horas; dois cardápios para os mesmos convidados.
        assert estimate(PricingModel.PER_HOUR, hours=5, quantity=2) == 100_000
        assert estimate(PricingModel.PER_PERSON, guests=10, quantity=2) == 200_000

    def test_the_minimum_is_charged_when_the_account_falls_short(self) -> None:
        assert estimate(PricingModel.PER_PERSON, guests=10, minimum=250_000) == 250_000
        assert estimate(PricingModel.PER_PERSON, guests=80, minimum=250_000) == 800_000

    def test_on_request_has_no_estimate(self) -> None:
        assert estimate(PricingModel.ON_REQUEST, price=None) is None
        # Nem com um preço esquecido no registro, nem com um mínimo.
        assert estimate(PricingModel.ON_REQUEST, price=0, minimum=50_000) is None

    @pytest.mark.parametrize(
        ("model", "guests", "hours"),
        [(PricingModel.PER_PERSON, None, 4), (PricingModel.PER_HOUR, 50, None)],
        ids=["sem convidados", "sem duração"],
    )
    def test_no_estimate_without_the_measure_the_model_needs(
        self, model: PricingModel, guests: int | None, hours: int | None
    ) -> None:
        # Não se inventa um valor: nem zero, nem o mínimo.
        assert estimate(model, minimum=250_000, guests=guests, hours=hours) is None

    def test_the_other_models_do_not_need_guests_or_hours(self) -> None:
        assert estimate(PricingModel.FIXED, guests=None, hours=None) == 10_000
        assert estimate(PricingModel.PER_UNIT, guests=None, hours=None, quantity=2) == 20_000


class TestPublicPrice:
    def test_on_request_goes_out_as_null_not_as_zero(self) -> None:
        assert public_price(PricingModel.ON_REQUEST, 0) is None

    @pytest.mark.parametrize("model", [m for m in PricingModel if m is not PricingModel.ON_REQUEST])
    def test_the_other_models_show_the_price(self, model: PricingModel) -> None:
        assert public_price(model, 12_345) == 12_345
