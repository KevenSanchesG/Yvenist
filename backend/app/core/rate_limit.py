"""Limite de requisições em memória (janela deslizante).

Protege login e cadastro contra força bruta. O estado fica na memória do
processo: com mais de uma instância da API cada uma conta separadamente, então
em produção com várias réplicas o limite deve ser reforçado no proxy/gateway ou
trocado por um contador compartilhado.
"""

import math
import threading
import time
from collections import deque
from collections.abc import Callable

from app.core.errors import TooManyRequestsError

_MAX_TRACKED_KEYS = 10_000


class RateLimiter:
    def __init__(
        self,
        *,
        limit: int,
        window_seconds: float = 60.0,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._limit = limit
        self._window = window_seconds
        self._clock = clock
        self._hits: dict[str, deque[float]] = {}
        self._lock = threading.Lock()

    def hit(self, key: str) -> None:
        """Registra uma tentativa; levanta ``TooManyRequestsError`` se passar do limite."""
        now = self._clock()
        with self._lock:
            hits = self._hits.setdefault(key, deque())
            self._discard_expired(hits, now)
            if len(hits) >= self._limit:
                retry_after = math.ceil(self._window - (now - hits[0]))
                raise TooManyRequestsError(max(retry_after, 1))
            hits.append(now)
            if len(self._hits) > _MAX_TRACKED_KEYS:
                self._purge(now)

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()

    def _discard_expired(self, hits: deque[float], now: float) -> None:
        while hits and now - hits[0] >= self._window:
            hits.popleft()

    def _purge(self, now: float) -> None:
        # Evita crescimento sem limite quando há muitas chaves distintas.
        for key in list(self._hits):
            hits = self._hits[key]
            self._discard_expired(hits, now)
            if not hits:
                del self._hits[key]
