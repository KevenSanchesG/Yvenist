"""O que cada tipo de item pede para entrar em uma festa. Sem banco e sem HTTP.

Um salão não se configura como um brinquedo: cada categoria tem a sua lista
curta de campos, e só eles. Incluir uma categoria é acrescentar uma entrada em
``_SPECS``; nada mais muda.

O app tem a mesma tabela (``item_configuration_spec.dart``), para montar o
formulário e validar antes de enviar. As duas têm de concordar: chave, tipo,
obrigatoriedade e limites.
"""

from collections.abc import Mapping
from dataclasses import dataclass, replace
from enum import StrEnum

from app.core.errors import UnprocessableError
from app.modules.catalog.pricing import PricingModel
from app.modules.catalog.reference_data import VENUE_CATEGORY

MAX_ITEM_QUANTITY = 999

# O valor de um campo: um número inteiro ou um texto.
Value = int | str
Configuration = Mapping[str, Value]

DURATION = "duration_hours"
NOTES = "notes"


class InvalidItemConfigurationError(UnprocessableError):
    code = "invalid_item_configuration"
    message = "Revise as informações do item."


class InvalidQuantityError(UnprocessableError):
    code = "invalid_quantity"
    message = f"A quantidade precisa ficar entre 1 e {MAX_ITEM_QUANTITY}."


class FieldKind(StrEnum):
    INTEGER = "integer"
    CHOICE = "choice"
    TEXT = "text"


@dataclass(frozen=True)
class Field:
    key: str
    kind: FieldKind
    required: bool = False
    # INTEGER: o intervalo aceito.
    minimum: int = 1
    maximum: int = 1
    # CHOICE: os valores aceitos.
    options: tuple[str, ...] = ()
    # TEXT: o tamanho máximo.
    max_length: int = 0


@dataclass(frozen=True)
class ItemSpec:
    fields: tuple[Field, ...]
    # Sem isto a quantidade é sempre 1: não faz sentido pedir "2 salões".
    allows_quantity: bool = False
    # O item é o lugar da festa: não entra sem a data e o número de convidados.
    requires_event_details: bool = False

    def field(self, key: str) -> Field | None:
        return next((field for field in self.fields if field.key == key), None)


def _duration(*, required: bool = False) -> Field:
    return Field(DURATION, FieldKind.INTEGER, required=required, minimum=1, maximum=24)


def _text(key: str, max_length: int, *, required: bool = False) -> Field:
    return Field(key, FieldKind.TEXT, required=required, max_length=max_length)


def _choice(key: str, *options: str, required: bool = False) -> Field:
    return Field(key, FieldKind.CHOICE, required=required, options=options)


_NOTES = _text(NOTES, 500)

_SPECS: dict[str, ItemSpec] = {
    VENUE_CATEGORY: ItemSpec(
        fields=(_duration(required=True), _text("requirements", 300), _NOTES),
        requires_event_details=True,
    ),
    "buffet": ItemSpec(
        fields=(
            _choice(
                "service_style", "plated", "self_service", "cocktail", "barbecue", required=True
            ),
            _text("menu", 200),
            _duration(),
            _NOTES,
        ),
    ),
    "kids": ItemSpec(
        fields=(
            _duration(required=True),
            _choice("age_range", "up_to_3", "from_4_to_7", "from_8_to_12", "all_ages"),
            _NOTES,
        ),
        allows_quantity=True,
    ),
    "attraction": ItemSpec(fields=(_duration(required=True), _NOTES)),
    "decoration": ItemSpec(
        fields=(
            _text("theme", 80, required=True),
            _choice("environment", "indoor", "outdoor", "both"),
            _text("items", 300),
            _text("customization", 300),
            _NOTES,
        ),
        allows_quantity=True,
    ),
    "dj": ItemSpec(fields=(_duration(required=True), _NOTES)),
    "staff": ItemSpec(fields=(_duration(required=True), _NOTES), allows_quantity=True),
    "security": ItemSpec(fields=(_duration(required=True), _NOTES), allows_quantity=True),
    "beauty": ItemSpec(fields=(_NOTES,), allows_quantity=True),
    "other": ItemSpec(fields=(_text("variation", 80), _NOTES), allows_quantity=True),
}

# Um serviço do próprio anunciante é um complemento do anúncio: os detalhes da
# categoria são combinados com o mesmo fornecedor. Só se pede o que o preço usa.
_OWN_SERVICE = ItemSpec(fields=(_NOTES,))


def spec_for(category: str, pricing_model: PricingModel, *, is_own_service: bool) -> ItemSpec:
    """O que um item desta categoria, cobrado deste jeito, pede.

    Uma categoria que a API ainda não conhece recebe o formulário de "outros".
    """
    base = _OWN_SERVICE if is_own_service else _SPECS.get(category, _SPECS["other"])
    fields = base.fields
    allows_quantity = base.allows_quantity

    if pricing_model is PricingModel.PER_HOUR:
        # Cobrado por hora, a duração deixa de ser opcional: sem ela não há
        # estimativa. Entra no formulário mesmo se a categoria não a previa.
        duration = replace(base.field(DURATION) or _duration(), required=True)
        fields = (duration, *(field for field in fields if field.key != DURATION))
    if pricing_model is PricingModel.PER_UNIT:
        allows_quantity = True

    return ItemSpec(
        fields=fields,
        allows_quantity=allows_quantity,
        requires_event_details=base.requires_event_details,
    )


def validate_item(
    spec: ItemSpec, *, quantity: int, configuration: Mapping[str, object]
) -> dict[str, Value]:
    """Confere a quantidade e devolve a configuração limpa, pronta para gravar.

    Texto sai sem espaços nas pontas; o que ficou vazio não é gravado. Assim
    duas configurações iguais são iguais também na comparação.
    """
    if quantity < 1 or quantity > MAX_ITEM_QUANTITY:
        raise InvalidQuantityError
    if quantity != 1 and not spec.allows_quantity:
        raise InvalidQuantityError("Este item não tem quantidade: é contratado uma vez só.")

    cleaned: dict[str, Value] = {}
    errors: list[dict[str, str]] = []

    for key in configuration:
        if spec.field(key) is None:
            errors.append({"field": key, "message": "Este item não tem esta informação."})

    for field in spec.fields:
        raw = configuration.get(field.key)
        if isinstance(raw, str):
            raw = raw.strip()
        if raw is None or raw == "":
            if field.required:
                errors.append({"field": field.key, "message": "Campo obrigatório."})
            continue
        problem = _problem(field, raw)
        if problem is not None:
            errors.append({"field": field.key, "message": problem})
        else:
            # _problem já garantiu o tipo.
            cleaned[field.key] = raw  # type: ignore[assignment]

    if errors:
        raise InvalidItemConfigurationError(details={"fields": errors})
    return cleaned


def _problem(field: Field, value: object) -> str | None:
    match field.kind:
        case FieldKind.INTEGER:
            # bool é um int em Python: "verdadeiro" não é uma duração.
            if not isinstance(value, int) or isinstance(value, bool):
                return "Informe um número inteiro."
            if not field.minimum <= value <= field.maximum:
                return f"Informe um valor de {field.minimum} a {field.maximum}."
        case FieldKind.CHOICE:
            if value not in field.options:
                return "Opção inválida."
        case FieldKind.TEXT:
            if not isinstance(value, str):
                return "Informe um texto."
            if len(value) > field.max_length:
                return f"Use no máximo {field.max_length} caracteres."
    return None
