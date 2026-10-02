"""Logs da aplicação e identificador de requisição.

Cada requisição recebe um id (``X-Request-ID``), devolvido no cabeçalho da
resposta e no corpo dos erros, para ligar o que o usuário viu ao que foi
registrado. O log de acesso nunca inclui corpo, query string ou cabeçalhos:
eles podem conter senha, token ou dados pessoais.
"""

import logging
import re
import time
import uuid

from starlette.types import ASGIApp, Message, Receive, Scope, Send

REQUEST_ID_HEADER = "x-request-id"
_SAFE_REQUEST_ID = re.compile(r"^[A-Za-z0-9._-]{1,64}$")

access_logger = logging.getLogger("yvenist.access")


def configure_logging(level: str) -> None:
    logging.basicConfig(
        level=level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


class RequestContextMiddleware:
    """Atribui o id da requisição, mede a duração e aplica cabeçalhos de segurança."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = self._incoming_request_id(scope) or uuid.uuid4().hex
        scope.setdefault("state", {})["request_id"] = request_id
        started = time.perf_counter()
        status_code = 500

        async def send_with_headers(message: Message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                headers = list(message.get("headers", []))
                headers.append((REQUEST_ID_HEADER.encode(), request_id.encode()))
                headers.append((b"x-content-type-options", b"nosniff"))
                headers.append((b"referrer-policy", b"no-referrer"))
                # Respostas da API são por usuário: nunca devem ir para cache
                # compartilhado.
                headers.append((b"cache-control", b"no-store"))
                message["headers"] = headers
            await send(message)

        try:
            await self.app(scope, receive, send_with_headers)
        finally:
            duration_ms = (time.perf_counter() - started) * 1000
            access_logger.info(
                "request_id=%s method=%s path=%s status=%s duration_ms=%.1f",
                request_id,
                scope["method"],
                scope["path"],
                status_code,
                duration_ms,
            )

    @staticmethod
    def _incoming_request_id(scope: Scope) -> str | None:
        for name, value in scope.get("headers", []):
            if name == REQUEST_ID_HEADER.encode():
                candidate: str = value.decode("latin-1")
                # Só aceita ids "bem comportados": o valor vai para o log.
                return candidate if _SAFE_REQUEST_ID.match(candidate) else None
        return None
