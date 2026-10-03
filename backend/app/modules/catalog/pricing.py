"""Como um anúncio cobra, e a estimativa que sai disso. Sem banco e sem HTTP.

A mesma conta existe no app (``Pricing``, em ``party_maker/domain``): as duas
têm de dar o mesmo resultado para a mesma entrada.
"""

from enum import StrEnum

# Preço máximo aceito para um anúncio ou serviço: R$ 1 milhão.
MAX_PRICE_CENTS = 100_000_000


class PricingModel(StrEnum):
    # Um valor pelo serviço inteiro: não muda com convidados, horas ou quantidade.
    FIXED = "fixed"
    PER_PERSON = "per_person"
    PER_HOUR = "per_hour"
    PER_UNIT = "per_unit"
    # Sob consulta: o fornecedor não publica preço. Não há o que estimar.
    ON_REQUEST = "on_request"


def public_price(model: PricingModel, cents: int) -> int | None:
    """O preço como sai da API: ``None`` quando o anúncio é sob consulta.

    O banco guarda zero nesse caso (a coluna ordena a vitrine); devolver o zero
    faria um cliente desatento mostrar "R$ 0,00" no lugar de "sob consulta".
    """
    return None if model is PricingModel.ON_REQUEST else cents


def estimate_cents(
    model: PricingModel,
    unit_price_cents: int | None,
    *,
    minimum_cents: int | None,
    guests: int | None,
    hours: int | None,
    quantity: int,
) -> int | None:
    """Estimativa em centavos, ou ``None`` quando não dá para estimar.

    Não dá quando o preço é sob consulta ou quando falta a medida de que o
    modelo depende (convidados, para "por pessoa"; horas, para "por hora").
    Nunca se inventa um valor no lugar do que falta.
    """
    if model is PricingModel.ON_REQUEST or unit_price_cents is None:
        return None

    match model:
        case PricingModel.FIXED:
            amount = unit_price_cents
        case PricingModel.PER_UNIT:
            amount = unit_price_cents * quantity
        case PricingModel.PER_PERSON:
            if guests is None:
                return None
            amount = unit_price_cents * guests * quantity
        case PricingModel.PER_HOUR:
            if hours is None:
                return None
            amount = unit_price_cents * hours * quantity

    if minimum_cents is not None:
        amount = max(amount, minimum_cents)
    return amount
