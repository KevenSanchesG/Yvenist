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

# Um ano, como recomenda a RFC 6797. Sem "preload": entrar na lista embutida dos
# navegadores é um compromisso do domínio inteiro, difícil de desfazer.
_HSTS_ONE_YEAR = b"max-age=31536000; includeSubDomains"

access_logger = logging.getLogger("yvenist.access")


def configure_logging(level: str) -> None:
    logging.basicConfig(
        level=level.upper(),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )


class RequestContextMiddleware:
    """Atribui o id da requisição, mede a duração e aplica cabeçalhos de segurança."""

    def __init__(self, app: ASGIApp, *, strict_transport_security: bool = False) -> None:
        self.app = app
        # Só em produção, onde a API fica atrás de https: avisa o navegador para
        # nunca mais tentar http neste endereço. Em desenvolvimento a API é
        # servida em http e o cabeçalho não faria sentido.
        self._strict_transport_security = strict_transport_security

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
                if self._strict_transport_security:
                    headers.append((b"strict-transport-security", _HSTS_ONE_YEAR))
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
