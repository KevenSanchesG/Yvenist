import pytest

from app.core.documents import (
    is_valid_cnpj,
    is_valid_cpf,
    is_valid_document,
    mask_document,
    normalize_document,
)
from tests.conftest import VALID_ALPHANUMERIC_CNPJ, VALID_CNPJ, VALID_CPFS


@pytest.mark.parametrize("cpf", VALID_CPFS)
def test_accepts_valid_cpf(cpf: str) -> None:
    assert is_valid_cpf(cpf)


def test_accepts_formatted_cpf() -> None:
    assert is_valid_cpf("529.982.247-25")


@pytest.mark.parametrize(
    "cpf",
    [
        "52998224724",  # dígito verificador errado
        "11111111111",  # todos os dígitos iguais
        "5299822472",  # curto demais
        "529982247255",  # longo demais
        "5299822472A",  # letra
        "",
    ],
)
def test_rejects_invalid_cpf(cpf: str) -> None:
    assert not is_valid_cpf(cpf)


def test_accepts_numeric_cnpj() -> None:
    assert is_valid_cnpj(VALID_CNPJ)
    assert is_valid_cnpj("11.222.333/0001-81")


def test_accepts_alphanumeric_cnpj() -> None:
    # Exemplo da documentação da Receita Federal para o formato de 2026.
    assert is_valid_cnpj(VALID_ALPHANUMERIC_CNPJ)
    assert is_valid_cnpj("12.abc.345/01de-35")


@pytest.mark.parametrize(
    "cnpj",
    [
        "11222333000180",  # dígito verificador errado
        "12ABC34501DE36",  # alfanumérico com dígito errado
        "00000000000000",
        "1122233300018",  # curto demais
        "112223330001AB",  # os dois últimos precisam ser dígitos
        "11222333000!81",
    ],
)
def test_rejects_invalid_cnpj(cnpj: str) -> None:
    assert not is_valid_cnpj(cnpj)


def test_validates_by_kind() -> None:
    assert is_valid_document("cpf", VALID_CPFS[0])
    assert is_valid_document("cnpj", VALID_CNPJ)
    assert not is_valid_document("cpf", VALID_CNPJ)
    assert not is_valid_document("cnpj", VALID_CPFS[0])


def test_normalizes_punctuation_and_case() -> None:
    assert normalize_document(" 529.982.247-25 ") == "52998224725"
    assert normalize_document("12.abc.345/01de-35") == "12ABC34501DE35"


def test_masks_everything_but_the_edges() -> None:
    assert mask_document("52998224725") == "529.***.***-25"
    assert mask_document("11222333000181") == "11.***.***/****-81"
    assert mask_document("123") == "***"
