"""Erros de aplicação e sua tradução para respostas HTTP.

Toda resposta de erro tem o mesmo formato::

    {"error": {"code": "party_not_found", "message": "Festa não encontrada."}}

``code`` é estável e serve para o cliente decidir o que fazer; ``message`` é o
texto em português que pode ser mostrado ao usuário.
"""

import logging
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

logger = logging.getLogger(__name__)


class AppError(Exception):
    status_code = 400
    code = "bad_request"
    message = "Requisição inválida."

    def __init__(
        self,
        message: str | None = None,
        *,
        code: str | None = None,
        details: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.message = message or self.message
        self.code = code or self.code
        self.details = details
        self.headers = headers
        super().__init__(self.message)


class UnauthorizedError(AppError):
    status_code = 401
    code = "unauthorized"
    message = "Autenticação necessária."

    def __init__(self, message: str | None = None, *, code: str | None = None) -> None:
        super().__init__(message, code=code, headers={"WWW-Authenticate": "Bearer"})


class ForbiddenError(AppError):
    status_code = 403
    code = "forbidden"
    message = "Você não tem permissão para esta ação."


class NotFoundError(AppError):
    status_code = 404
    code = "not_found"
    message = "Recurso não encontrado."


class ConflictError(AppError):
    status_code = 409
    code = "conflict"
    message = "A operação conflita com o estado atual do recurso."


class UnprocessableError(AppError):
    status_code = 422
    code = "unprocessable"
    message = "Os dados enviados não puderam ser processados."


class TooManyRequestsError(AppError):
    status_code = 429
    code = "too_many_requests"
    message = "Muitas tentativas. Aguarde um pouco e tente novamente."

    def __init__(self, retry_after_seconds: int) -> None:
        super().__init__(headers={"Retry-After": str(retry_after_seconds)})


def _error_body(
    request: Request,
    *,
    code: str,
    message: str,
    details: dict[str, Any] | None = None,
) -> dict[str, Any]:
    error: dict[str, Any] = {"code": code, "message": message}
    if details:
        error["details"] = details
    request_id = getattr(request.state, "request_id", None)
    if request_id:
        error["request_id"] = request_id
    return {"error": error}


# Erros HTTP levantados pelo próprio framework (rota inexistente, método errado).
_HTTP_ERRORS = {
    400: ("bad_request", "Requisição inválida."),
    401: ("unauthorized", "Autenticação necessária."),
    403: ("forbidden", "Você não tem permissão para esta ação."),
    404: ("not_found", "Recurso não encontrado."),
    405: ("method_not_allowed", "Método não permitido."),
}


def _field_path(location: tuple[Any, ...]) -> str:
    # ("body", "items", 0, "quantity") -> "items.0.quantity"
    parts = [str(part) for part in location if part not in {"body", "query", "path"}]
    return ".".join(parts)


def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(request, code=exc.code, message=exc.message, details=exc.details),
            headers=exc.headers,
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation_error(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        # Não devolvemos ``input``: ele pode conter a senha que o cliente enviou.
        fields = [
            {"field": _field_path(tuple(error["loc"])), "message": error["msg"]}
            for error in exc.errors()
        ]
        return JSONResponse(
            status_code=422,
            content=_error_body(
                request,
                code="validation_error",
                message="Alguns campos estão inválidos.",
                details={"fields": fields},
            ),
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        code, message = _HTTP_ERRORS.get(exc.status_code, ("http_error", "Erro na requisição."))
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_body(request, code=code, message=message),
            headers=exc.headers,
        )

    @app.exception_handler(Exception)
    async def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
        # O detalhe fica só no log; o cliente recebe uma mensagem genérica.
        logger.exception("Erro não tratado em %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=500,
            content=_error_body(
                request,
                code="internal_error",
                message="Erro interno. Tente novamente em instantes.",
            ),
        )
