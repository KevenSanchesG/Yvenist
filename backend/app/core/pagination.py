"""Paginação por cursor (keyset).

Em vez de ``OFFSET``, que obriga o banco a percorrer e descartar todas as linhas
anteriores, o cursor guarda os valores de ordenação do último item devolvido e a
próxima página começa logo depois dele. O custo não cresce com a profundidade e
a listagem não repete nem pula itens quando novos registros entram.
"""

import base64
import binascii
import json
import uuid
from dataclasses import dataclass

from app.core.errors import UnprocessableError

DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 50


@dataclass(frozen=True)
class Cursor:
    sort: str
    key: int | float | str
    id: uuid.UUID


class InvalidCursorError(UnprocessableError):
    code = "invalid_cursor"
    message = "Cursor de paginação inválido."


def encode_cursor(cursor: Cursor) -> str:
    payload = json.dumps({"s": cursor.sort, "k": cursor.key, "i": cursor.id.hex})
    return base64.urlsafe_b64encode(payload.encode()).decode().rstrip("=")


def decode_cursor(value: str, *, expected_sort: str) -> Cursor:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded.encode()))
        cursor = Cursor(sort=payload["s"], key=payload["k"], id=uuid.UUID(payload["i"]))
    except (binascii.Error, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise InvalidCursorError from exc

    if not isinstance(cursor.key, int | float | str) or isinstance(cursor.key, bool):
        raise InvalidCursorError
    # Um cursor gerado para uma ordenação não vale para outra.
    if cursor.sort != expected_sort:
        raise InvalidCursorError
    return cursor
