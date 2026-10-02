"""Dependências do FastAPI compartilhadas pelas rotas."""

from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Header, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.database import session_scope
from app.core.errors import ForbiddenError, UnauthorizedError
from app.core.security import InvalidAccessTokenError, PasswordHasher, decode_access_token
from app.modules.accounts.models import User

_bearer_scheme = HTTPBearer(auto_error=False, description="Token de acesso (JWT).")


def get_settings(request: Request) -> Settings:
    settings: Settings = request.app.state.settings
    return settings


def get_db(request: Request) -> Iterator[Session]:
    yield from session_scope(request.app.state.session_factory)


def get_password_hasher(request: Request) -> PasswordHasher:
    hasher: PasswordHasher = request.app.state.password_hasher
    return hasher


SettingsDep = Annotated[Settings, Depends(get_settings)]
DbSession = Annotated[Session, Depends(get_db)]
PasswordHasherDep = Annotated[PasswordHasher, Depends(get_password_hasher)]
UserAgent = Annotated[str | None, Header(alias="User-Agent")]
Credentials = Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)]


class InvalidTokenError(UnauthorizedError):
    code = "invalid_token"
    message = "Sessão inválida ou expirada."


def _authenticate(
    credentials: HTTPAuthorizationCredentials, db: Session, settings: Settings
) -> User:
    try:
        claims = decode_access_token(
            credentials.credentials,
            secret=settings.jwt_secret.get_secret_value(),
        )
    except InvalidAccessTokenError as exc:
        raise InvalidTokenError from exc

    user = db.get(User, claims.user_id)
    # A conta pode ter sido apagada, desativada ou trocado de senha depois que o
    # token foi emitido; por isso o estado atual é conferido a cada requisição.
    if user is None or not user.is_active or user.token_version != claims.token_version:
        raise InvalidTokenError
    return user


def get_current_user(credentials: Credentials, db: DbSession, settings: SettingsDep) -> User:
    if credentials is None:
        raise UnauthorizedError
    return _authenticate(credentials, db, settings)


def get_optional_user(
    credentials: Credentials, db: DbSession, settings: SettingsDep
) -> User | None:
    """Para rotas públicas que mostram algo a mais a quem está autenticado."""
    if credentials is None:
        return None
    return _authenticate(credentials, db, settings)


CurrentUser = Annotated[User, Depends(get_current_user)]
OptionalUser = Annotated[User | None, Depends(get_optional_user)]


def get_admin_user(user: CurrentUser) -> User:
    if not user.is_admin:
        raise ForbiddenError
    return user


AdminUser = Annotated[User, Depends(get_admin_user)]


def _client_ip(request: Request) -> str:
    # Atrás de um proxy, o uvicorn deve rodar com --proxy-headers e
    # --forwarded-allow-ips para que este seja o IP real do cliente.
    return request.client.host if request.client else "unknown"


def limit_login(request: Request) -> None:
    if request.app.state.settings.rate_limit_enabled:
        request.app.state.login_limiter.hit(_client_ip(request))


def limit_register(request: Request) -> None:
    if request.app.state.settings.rate_limit_enabled:
        request.app.state.register_limiter.hit(_client_ip(request))
