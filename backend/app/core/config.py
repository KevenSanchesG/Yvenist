"""Configuração da aplicação, lida de variáveis de ambiente (prefixo ``YVENIST_``)."""

from typing import Annotated, Literal, Self

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

# Segredo usado apenas em desenvolvimento e testes. Em produção a aplicação
# se recusa a subir com ele (veja ``Settings._validate_production``).
INSECURE_DEV_SECRET = "dev-only-insecure-secret-change-me-0123456789"  # noqa: S105

MIN_JWT_SECRET_LENGTH = 32


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="YVENIST_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    env: Literal["development", "test", "production"] = "development"
    log_level: str = "INFO"

    database_url: str = "sqlite:///./yvenist.db"
    db_pool_size: int = Field(default=10, ge=1, le=100)
    db_max_overflow: int = Field(default=20, ge=0, le=100)

    jwt_secret: SecretStr = SecretStr(INSECURE_DEV_SECRET)
    access_token_ttl_minutes: int = Field(default=15, ge=1, le=24 * 60)
    refresh_token_ttl_days: int = Field(default=30, ge=1, le=365)

    # "test" usa parâmetros baratos de Argon2 só para a suíte rodar rápido.
    password_hash_profile: Literal["recommended", "test"] = "recommended"  # noqa: S105

    # Origens autorizadas para CORS (necessário apenas para o app web).
    # Aceita lista separada por vírgulas: "http://localhost:5000,https://app.exemplo".
    cors_origins: Annotated[list[str], NoDecode] = []

    # None = documentação interativa ligada fora de produção.
    docs_enabled: bool | None = None

    rate_limit_enabled: bool = True
    login_rate_limit_per_minute: int = Field(default=10, ge=1)
    register_rate_limit_per_minute: int = Field(default=5, ge=1)

    terms_version: str = "2026-10"

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _split_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @model_validator(mode="after")
    def _validate_production(self) -> Self:
        if self.env != "production":
            return self
        secret = self.jwt_secret.get_secret_value()
        if secret == INSECURE_DEV_SECRET or len(secret) < MIN_JWT_SECRET_LENGTH:
            raise ValueError(
                "YVENIST_JWT_SECRET deve ser definido em produção com pelo menos "
                f"{MIN_JWT_SECRET_LENGTH} caracteres aleatórios."
            )
        if self.password_hash_profile != "recommended":  # noqa: S105
            raise ValueError("YVENIST_PASSWORD_HASH_PROFILE=test não é permitido em produção.")
        if "*" in self.cors_origins:
            raise ValueError("CORS com origem '*' não é permitido em produção.")
        return self

    @property
    def is_production(self) -> bool:
        return self.env == "production"

    @property
    def show_docs(self) -> bool:
        if self.docs_enabled is not None:
            return self.docs_enabled
        return not self.is_production

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")
