"""Montagem da aplicação FastAPI."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app import models  # noqa: F401  (registra as tabelas)
from app.api.router import api_router
from app.core.config import Settings
from app.core.database import create_db_engine, create_session_factory
from app.core.errors import register_error_handlers
from app.core.logging import RequestContextMiddleware, configure_logging
from app.core.rate_limit import RateLimiter
from app.core.security import PasswordHasher

logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    configure_logging(settings.log_level)

    engine = create_db_engine(
        settings.database_url,
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
    )

    @asynccontextmanager
    async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
        if settings.is_production and settings.is_sqlite:
            logger.warning(
                "Produção rodando com SQLite: use PostgreSQL para ter concorrência real."
            )
        yield
        engine.dispose()

    app = FastAPI(
        title="Yvenist API",
        version="0.1.0",
        description="API do Yvenist, o marketplace de eventos e festas.",
        lifespan=lifespan,
        docs_url="/docs" if settings.show_docs else None,
        redoc_url=None,
        openapi_url="/openapi.json" if settings.show_docs else None,
    )

    app.state.settings = settings
    app.state.engine = engine
    app.state.session_factory = create_session_factory(engine)
    app.state.password_hasher = PasswordHasher(settings.password_hash_profile)
    app.state.login_limiter = RateLimiter(limit=settings.login_rate_limit_per_minute)
    app.state.register_limiter = RateLimiter(limit=settings.register_rate_limit_per_minute)

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            # A autenticação é por cabeçalho Authorization, não por cookie.
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
            # O navegador só mostra ao app os cabeçalhos de resposta listados
            # aqui: o tempo de espera de um 429 e o id da requisição.
            expose_headers=["Retry-After", "X-Request-ID"],
        )
    # Adicionado por último para ser o mais externo: também cobre as respostas
    # geradas pelo CORS e pelos tratadores de erro.
    app.add_middleware(RequestContextMiddleware, strict_transport_security=settings.is_production)

    register_error_handlers(app)
    app.include_router(api_router)

    @app.get("/health/live", tags=["Saúde"], summary="O processo está no ar")
    def live() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/health/ready", tags=["Saúde"], summary="O banco está respondendo")
    def ready(request: Request) -> JSONResponse:
        try:
            with request.app.state.engine.connect() as connection:
                connection.execute(text("SELECT 1"))
        except SQLAlchemyError:
            logger.exception("Banco de dados indisponível")
            return JSONResponse(status_code=503, content={"status": "unavailable"})
        return JSONResponse(content={"status": "ok"})

    return app


def get_app() -> FastAPI:
    """Fábrica usada pelo uvicorn: ``uvicorn app.main:get_app --factory``."""
    return create_app()
