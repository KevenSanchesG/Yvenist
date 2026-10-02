"""Senhas, tokens de acesso (JWT) e tokens de renovação.

Decisões, seguindo o tutorial oficial do FastAPI e as recomendações da OWASP:

- senhas com Argon2id (``pwdlib``), nunca reversíveis;
- token de acesso JWT curto, assinado com HS256 e com o algoritmo fixado na
  validação (um token com ``alg`` diferente é rejeitado);
- token de renovação opaco e aleatório; o banco guarda só o SHA-256 dele, então
  um vazamento do banco não entrega sessões válidas.
"""

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Literal

import jwt
from jwt.exceptions import InvalidTokenError
from pwdlib import PasswordHash
from pwdlib.hashers.argon2 import Argon2Hasher

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_TYPE = "access"  # noqa: S105

PasswordHashProfile = Literal["recommended", "test"]


class InvalidAccessTokenError(Exception):
    """O token de acesso é inválido, expirou ou não é um token de acesso."""


@dataclass(frozen=True)
class AccessTokenClaims:
    user_id: uuid.UUID
    # Versão dos tokens do usuário quando este foi emitido. Trocar a senha
    # incrementa a versão no banco e invalida na hora os tokens antigos.
    token_version: int
    expires_at: datetime


class PasswordHasher:
    def __init__(self, profile: PasswordHashProfile = "recommended") -> None:
        if profile == "test":
            # Parâmetros mínimos: só para a suíte de testes não gastar segundos
            # em cada cadastro. Bloqueado em produção pela configuração.
            self._hash = PasswordHash((Argon2Hasher(time_cost=1, memory_cost=8, parallelism=1),))
        else:
            self._hash = PasswordHash.recommended()
        # Hash de uma senha qualquer, verificado quando o e-mail não existe, para
        # que o tempo de resposta não revele quais e-mails estão cadastrados.
        self._dummy_hash = self._hash.hash(secrets.token_urlsafe(16))

    def hash(self, password: str) -> str:
        return self._hash.hash(password)

    def verify(self, password: str, password_hash: str) -> tuple[bool, str | None]:
        """Confere a senha; devolve também um hash novo se o antigo estiver defasado."""
        return self._hash.verify_and_update(password, password_hash)

    def verify_dummy(self, password: str) -> None:
        self._hash.verify(password, self._dummy_hash)


def create_access_token(
    *,
    user_id: uuid.UUID,
    token_version: int,
    secret: str,
    ttl: timedelta,
    now: datetime | None = None,
) -> tuple[str, datetime]:
    issued_at = now or datetime.now(UTC)
    expires_at = issued_at + ttl
    payload = {
        "sub": str(user_id),
        "ver": token_version,
        "iat": issued_at,
        "exp": expires_at,
        "typ": ACCESS_TOKEN_TYPE,
    }
    return jwt.encode(payload, secret, algorithm=JWT_ALGORITHM), expires_at


def decode_access_token(token: str, *, secret: str) -> AccessTokenClaims:
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=[JWT_ALGORITHM],
            options={"require": ["sub", "iat", "exp"]},
        )
        version = payload.get("ver")
        if payload.get("typ") != ACCESS_TOKEN_TYPE or not isinstance(version, int):
            raise InvalidAccessTokenError
        return AccessTokenClaims(
            user_id=uuid.UUID(payload["sub"]),
            token_version=version,
            expires_at=datetime.fromtimestamp(payload["exp"], UTC),
        )
    except (InvalidTokenError, ValueError, TypeError) as exc:
        raise InvalidAccessTokenError from exc


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
