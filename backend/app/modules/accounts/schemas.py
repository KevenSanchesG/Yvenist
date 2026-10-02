import re
import uuid
from datetime import date, datetime
from typing import Annotated

from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.modules.accounts.passwords import COMMON_PASSWORD_MESSAGE, is_too_common

PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128


def _clean_name(value: str) -> str:
    cleaned = " ".join(value.split())
    if len(cleaned) < 2:
        raise ValueError("Informe o nome completo.")
    return cleaned


def _validate_password(value: str) -> str:
    if not value.strip():
        raise ValueError("A senha não pode ser só de espaços.")
    if is_too_common(value):
        raise ValueError(COMMON_PASSWORD_MESSAGE)
    return value


def _normalize_phone(value: str | None) -> str | None:
    if value is None:
        return None
    digits = re.sub(r"\D", "", value)
    if not digits:
        return None
    # DDD + número (10 ou 11 dígitos), com ou sem o código do país (55).
    if not 10 <= len(digits) <= 13:
        raise ValueError("Telefone inválido.")
    return digits


FullName = Annotated[str, Field(max_length=120), AfterValidator(_clean_name)]
# Tamanho mínimo e uma lista de senhas muito comuns: a recomendação atual
# (NIST 800-63B) é essa, e não regras de composição, que empurram o usuário
# para senhas previsíveis.
NewPassword = Annotated[
    str,
    Field(min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH),
    AfterValidator(_validate_password),
]
CurrentPassword = Annotated[str, Field(min_length=1, max_length=PASSWORD_MAX_LENGTH)]
RefreshTokenValue = Annotated[str, Field(min_length=20, max_length=200)]


class RegisterRequest(BaseModel):
    email: EmailStr
    password: NewPassword
    full_name: FullName
    accept_terms: bool

    @field_validator("accept_terms")
    @classmethod
    def _terms_must_be_accepted(cls, value: bool) -> bool:
        if not value:
            raise ValueError("É preciso aceitar os termos de uso e a política de privacidade.")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: CurrentPassword


class RefreshRequest(BaseModel):
    refresh_token: RefreshTokenValue


class LogoutRequest(BaseModel):
    refresh_token: RefreshTokenValue


class UpdateProfileRequest(BaseModel):
    """Atualização parcial: só os campos enviados são alterados."""

    full_name: FullName | None = None
    phone: Annotated[str | None, Field(max_length=25), AfterValidator(_normalize_phone)] = None
    birth_date: date | None = None

    @field_validator("birth_date")
    @classmethod
    def _birth_date_in_the_past(cls, value: date | None) -> date | None:
        if value is not None and not date(1900, 1, 1) <= value <= date.today():  # noqa: DTZ011
            raise ValueError("Data de nascimento inválida.")
        return value


class ChangePasswordRequest(BaseModel):
    current_password: CurrentPassword
    new_password: NewPassword


class DeleteAccountRequest(BaseModel):
    password: CurrentPassword


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    full_name: str
    phone: str | None
    birth_date: date | None
    is_admin: bool
    created_at: datetime


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"  # noqa: S105
    # Segundos até o token de acesso expirar.
    expires_in: int


class AuthResponse(BaseModel):
    user: UserResponse
    tokens: TokenPair


class SessionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    user_agent: str | None
    created_at: datetime
    expires_at: datetime
