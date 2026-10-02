"""Validação de CPF e CNPJ.

O CNPJ passou a aceitar letras nas 12 primeiras posições em julho de 2026
(Instrução Normativa RFB nº 2.229/2024). O cálculo dos dígitos verificadores
continua sendo módulo 11, mas cada caractere vale ``código ASCII - 48``: os
dígitos mantêm o valor de sempre e as letras valem A=17, B=18...
"""

import re
from typing import Literal

DocumentKind = Literal["cpf", "cnpj"]

_CNPJ_PATTERN = re.compile(r"^[0-9A-Z]{12}[0-9]{2}$")
_CNPJ_WEIGHTS = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2)


def normalize_document(value: str) -> str:
    """Remove pontuação e espaços; letras ficam maiúsculas."""
    return re.sub(r"[^0-9A-Za-z]", "", value).upper()


def is_valid_cpf(value: str) -> bool:
    cpf = normalize_document(value)
    if len(cpf) != 11 or not cpf.isdigit() or cpf == cpf[0] * 11:
        return False

    for position in (9, 10):
        total = sum(
            int(digit) * (position + 1 - index) for index, digit in enumerate(cpf[:position])
        )
        check_digit = (total * 10) % 11 % 10
        if check_digit != int(cpf[position]):
            return False
    return True


def is_valid_cnpj(value: str) -> bool:
    cnpj = normalize_document(value)
    if not _CNPJ_PATTERN.match(cnpj) or cnpj == cnpj[0] * 14:
        return False

    for position in (12, 13):
        weights = _CNPJ_WEIGHTS[13 - position :]
        total = sum(
            (ord(char) - 48) * weight for char, weight in zip(cnpj[:position], weights, strict=True)
        )
        remainder = total % 11
        check_digit = 0 if remainder < 2 else 11 - remainder
        if check_digit != int(cnpj[position]):
            return False
    return True


def is_valid_document(kind: DocumentKind, value: str) -> bool:
    return is_valid_cpf(value) if kind == "cpf" else is_valid_cnpj(value)


def mask_document(value: str) -> str:
    """Esconde o miolo do documento: só o começo e o fim ficam legíveis."""
    document = normalize_document(value)
    if len(document) == 11:
        return f"{document[:3]}.***.***-{document[9:]}"
    if len(document) == 14:
        return f"{document[:2]}.***.***/****-{document[12:]}"
    return "*" * len(document)
