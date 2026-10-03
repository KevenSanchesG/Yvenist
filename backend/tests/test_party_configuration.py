"""O que cada categoria de item pede, testado direto: sem banco nem HTTP."""

import pytest

from app.modules.catalog.pricing import PricingModel
from app.modules.catalog.reference_data import CATEGORIES
from app.modules.parties.configuration import (
    InvalidItemConfigurationError,
    InvalidQuantityError,
    spec_for,
    validate_item,
)

FIXED = PricingModel.FIXED


def keys(category: str, model: PricingModel = FIXED, *, is_own_service: bool = False) -> list[str]:
    spec = spec_for(category, model, is_own_service=is_own_service)
    return [field.key for field in spec.fields]


def required(category: str, model: PricingModel = FIXED) -> list[str]:
    spec = spec_for(category, model, is_own_service=False)
    return [field.key for field in spec.fields if field.required]


class TestSpecs:
    def test_every_catalog_category_has_its_own_short_form(self) -> None:
        for category in CATEGORIES:
            spec = spec_for(category["slug"], FIXED, is_own_service=False)

            assert spec.fields, category["slug"]
            # Toda categoria tem onde escrever uma observação, e nenhuma pede
            # mais do que uma tela curta.
            assert spec.fields[-1].key == "notes"
            assert len(spec.fields) <= 5

    def test_a_venue_asks_for_what_a_venue_needs(self) -> None:
        spec = spec_for("venue", FIXED, is_own_service=False)

        assert keys("venue") == ["duration_hours", "requirements", "notes"]
        assert required("venue") == ["duration_hours"]
        assert spec.requires_event_details is True
        assert spec.allows_quantity is False

    def test_each_category_is_different(self) -> None:
        assert keys("buffet") == ["service_style", "menu", "duration_hours", "notes"]
        assert keys("kids") == ["duration_hours", "age_range", "notes"]
        assert keys("decoration") == ["theme", "environment", "items", "customization", "notes"]
        assert keys("other") == ["variation", "notes"]
        assert required("decoration") == ["theme"]
        assert required("other") == []

    @pytest.mark.parametrize("category", ["kids", "decoration", "staff", "security", "other"])
    def test_quantity_where_more_than_one_makes_sense(self, category: str) -> None:
        assert spec_for(category, FIXED, is_own_service=False).allows_quantity is True

    @pytest.mark.parametrize("category", ["venue", "buffet", "attraction", "dj"])
    def test_no_quantity_where_it_does_not(self, category: str) -> None:
        assert spec_for(category, FIXED, is_own_service=False).allows_quantity is False

    def test_a_category_the_api_does_not_know_gets_the_generic_form(self) -> None:
        assert keys("categoria-nova") == keys("other")

    def test_charging_per_hour_makes_the_duration_required_everywhere(self) -> None:
        # Na categoria que já tinha o campo, ele deixa de ser opcional...
        assert "duration_hours" not in required("buffet")
        assert "duration_hours" in required("buffet", PricingModel.PER_HOUR)
        # ...e na que não tinha, ele entra.
        assert keys("other", PricingModel.PER_HOUR) == ["duration_hours", "variation", "notes"]

    def test_charging_per_unit_brings_the_quantity(self) -> None:
        assert spec_for("dj", PricingModel.PER_UNIT, is_own_service=False).allows_quantity is True

    def test_an_own_service_asks_only_for_what_its_price_uses(self) -> None:
        # Os detalhes da categoria são combinados com o mesmo fornecedor.
        assert keys("buffet", is_own_service=True) == ["notes"]
        assert keys("attraction", PricingModel.PER_HOUR, is_own_service=True) == [
            "duration_hours",
            "notes",
        ]
        per_unit = spec_for("other", PricingModel.PER_UNIT, is_own_service=True)
        assert per_unit.allows_quantity is True
        assert spec_for("venue", FIXED, is_own_service=True).requires_event_details is False


class TestValidation:
    def test_returns_the_clean_configuration(self) -> None:
        spec = spec_for("decoration", FIXED, is_own_service=False)

        cleaned = validate_item(
            spec,
            quantity=2,
            configuration={
                "theme": "  Safari  ",
                "environment": "outdoor",
                "items": "   ",
                "notes": None,
            },
        )

        # Sem espaços nas pontas; o que ficou vazio não é gravado.
        assert cleaned == {"theme": "Safari", "environment": "outdoor"}

    def test_reports_every_problem_at_once(self) -> None:
        spec = spec_for("buffet", PricingModel.PER_HOUR, is_own_service=False)

        with pytest.raises(InvalidItemConfigurationError) as error:
            validate_item(
                spec,
                quantity=1,
                configuration={"service_style": "rodizio", "menu": "x" * 201, "cor": "azul"},
            )

        assert error.value.details == {
            "fields": [
                {"field": "cor", "message": "Este item não tem esta informação."},
                {"field": "duration_hours", "message": "Campo obrigatório."},
                {"field": "service_style", "message": "Opção inválida."},
                {"field": "menu", "message": "Use no máximo 200 caracteres."},
            ]
        }

    @pytest.mark.parametrize(
        ("value", "message"),
        [
            (0, "Informe um valor de 1 a 24."),
            (25, "Informe um valor de 1 a 24."),
            ("4", "Informe um número inteiro."),
            (4.5, "Informe um número inteiro."),
            (True, "Informe um número inteiro."),
        ],
    )
    def test_a_duration_is_a_whole_number_of_hours_within_a_day(
        self, value: object, message: str
    ) -> None:
        spec = spec_for("dj", FIXED, is_own_service=False)

        with pytest.raises(InvalidItemConfigurationError) as error:
            validate_item(spec, quantity=1, configuration={"duration_hours": value})

        assert error.value.details == {"fields": [{"field": "duration_hours", "message": message}]}

    def test_a_text_field_does_not_take_a_number(self) -> None:
        spec = spec_for("other", FIXED, is_own_service=False)

        with pytest.raises(InvalidItemConfigurationError):
            validate_item(spec, quantity=1, configuration={"variation": 42})

    @pytest.mark.parametrize("quantity", [0, -1, 1000])
    def test_quantity_out_of_range(self, quantity: int) -> None:
        spec = spec_for("other", FIXED, is_own_service=False)

        with pytest.raises(InvalidQuantityError):
            validate_item(spec, quantity=quantity, configuration={})

    def test_quantity_above_one_only_where_allowed(self) -> None:
        dj = spec_for("dj", FIXED, is_own_service=False)

        with pytest.raises(InvalidQuantityError) as error:
            validate_item(dj, quantity=2, configuration={"duration_hours": 4})

        assert "uma vez só" in error.value.message
