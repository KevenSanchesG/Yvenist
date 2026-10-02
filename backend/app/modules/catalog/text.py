"""Normalização de texto para busca."""

import unicodedata


def normalize_text(value: str) -> str:
    """Minúsculas, sem acentos e com espaços simples.

    Aplicada tanto ao texto indexado quanto ao termo digitado, faz "salao"
    encontrar "Salão" em qualquer banco, sem depender de collation.
    """
    decomposed = unicodedata.normalize("NFKD", value)
    without_accents = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join(without_accents.lower().split())


def build_search_text(*parts: str | None) -> str:
    return normalize_text(" ".join(part for part in parts if part))
