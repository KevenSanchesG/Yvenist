"""Testes das peças de infraestrutura que não dependem de banco nem de HTTP."""

import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from pydantic import ValidationError

from app.core.config import INSECURE_DEV_SECRET, Settings
from app.core.errors import TooManyRequestsError
from app.core.pagination import Cursor, InvalidCursorError, decode_cursor, encode_cursor
from app.core.rate_limit import RateLimiter
from app.core.security import (
    InvalidAccessTokenError,
    PasswordHasher,
    create_access_token,
    decode_access_token,
    generate_refresh_token,
    hash_refresh_token,
)
from app.modules.catalog.text import build_search_text, normalize_text
from tests.conftest import TEST_JWT_SECRET, make_settings

USER_ID = uuid.UUID("11111111-1111-1111-1111-111111111111")


class TestSettings:
    def test_production_refuses_the_development_secret(self) -> None:
        with pytest.raises(ValidationError, match="YVENIST_JWT_SECRET"):
            make_settings(
                env="production",
                jwt_secret=INSECURE_DEV_SECRET,
                password_hash_profile="recommended",
            )

    def test_production_refuses_a_short_secret(self) -> None:
        with pytest.raises(ValidationError, match="YVENIST_JWT_SECRET"):
            make_settings(env="production", jwt_secret="curto", password_hash_profile="recommended")

    def test_production_refuses_the_test_hash_profile(self) -> None:
        with pytest.raises(ValidationError, match="PASSWORD_HASH_PROFILE"):
            make_settings(env="production", password_hash_profile="test")

    def test_production_refuses_wildcard_cors(self) -> None:
        with pytest.raises(ValidationError, match="CORS"):
            make_settings(env="production", password_hash_profile="recommended", cors_origins=["*"])

    def test_production_accepts_a_strong_configuration(self) -> None:
        settings = make_settings(env="production", password_hash_profile="recommended")

        assert settings.is_production
        assert not settings.show_docs

    def test_docs_are_on_outside_production_and_can_be_forced(self) -> None:
        assert make_settings().show_docs
        assert not make_settings(docs_enabled=False).show_docs

    def test_cors_origins_accept_a_comma_separated_list(self) -> None:
        settings = make_settings(cors_origins="http://localhost:5000, https://app.exemplo ,")

        assert settings.cors_origins == ["http://localhost:5000", "https://app.exemplo"]

    def test_reads_values_from_the_environment(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("YVENIST_ACCESS_TOKEN_TTL_MINUTES", "5")

        assert Settings(_env_file=None).access_token_ttl_minutes == 5


class TestPasswordHasher:
    def test_hash_is_not_the_password_and_verifies(self) -> None:
        hasher = PasswordHasher("test")

        hashed = hasher.hash("senha-segura-123")

        assert hashed != "senha-segura-123"
        assert hashed.startswith("$argon2id$")
        assert hasher.verify("senha-segura-123", hashed)[0]
        assert not hasher.verify("outra-senha", hashed)[0]

    def test_same_password_gets_different_hashes(self) -> None:
        hasher = PasswordHasher("test")

        assert hasher.hash("senha-segura-123") != hasher.hash("senha-segura-123")

    def test_dummy_verification_never_raises(self) -> None:
        PasswordHasher("test").verify_dummy("qualquer-coisa")

    def test_recommended_profile_meets_owasp_minimum(self) -> None:
        # OWASP: Argon2id com pelo menos 19 MiB de memória e 2 iterações.
        hashed = PasswordHasher("recommended").hash("senha-segura-123")
        params = dict(part.split("=") for part in hashed.split("$")[3].split(","))

        assert hashed.startswith("$argon2id$")
        assert int(params["m"]) >= 19 * 1024
        assert int(params["t"]) >= 2


class TestAccessToken:
    def _token(self, **overrides: object) -> str:
        arguments: dict[str, object] = {
            "user_id": USER_ID,
            "token_version": 3,
            "secret": TEST_JWT_SECRET,
            "ttl": timedelta(minutes=15),
        }
        arguments.update(overrides)
        return create_access_token(**arguments)[0]  # type: ignore[arg-type]

    def test_round_trip(self) -> None:
        claims = decode_access_token(self._token(), secret=TEST_JWT_SECRET)

        assert claims.user_id == USER_ID
        assert claims.token_version == 3
        assert claims.expires_at > datetime.now(UTC)

    def test_rejects_expired_token(self) -> None:
        token = self._token(now=datetime.now(UTC) - timedelta(hours=1))

        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(token, secret=TEST_JWT_SECRET)

    def test_rejects_token_signed_with_another_secret(self) -> None:
        token = self._token(secret="another-secret-with-at-least-32-chars!!")

        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(token, secret=TEST_JWT_SECRET)

    def test_rejects_unsigned_token(self) -> None:
        # Ataque clássico: token com alg=none, sem assinatura.
        payload = {
            "sub": str(USER_ID),
            "ver": 1,
            "typ": "access",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        }
        token = jwt.encode(payload, key="", algorithm="none")

        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(token, secret=TEST_JWT_SECRET)

    def test_rejects_token_of_another_type(self) -> None:
        payload = {
            "sub": str(USER_ID),
            "ver": 1,
            "typ": "refresh",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        }
        token = jwt.encode(payload, TEST_JWT_SECRET, algorithm="HS256")

        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(token, secret=TEST_JWT_SECRET)

    @pytest.mark.parametrize("missing", ["sub", "exp", "iat", "ver"])
    def test_rejects_token_missing_a_required_claim(self, missing: str) -> None:
        payload: dict[str, object] = {
            "sub": str(USER_ID),
            "ver": 1,
            "typ": "access",
            "iat": datetime.now(UTC),
            "exp": datetime.now(UTC) + timedelta(minutes=5),
        }
        del payload[missing]
        token = jwt.encode(payload, TEST_JWT_SECRET, algorithm="HS256")

        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(token, secret=TEST_JWT_SECRET)

    @pytest.mark.parametrize("garbage", ["", "abc", "a.b.c", "Bearer x"])
    def test_rejects_garbage(self, garbage: str) -> None:
        with pytest.raises(InvalidAccessTokenError):
            decode_access_token(garbage, secret=TEST_JWT_SECRET)


class TestRefreshToken:
    def test_tokens_are_long_and_unique(self) -> None:
        tokens = {generate_refresh_token() for _ in range(50)}

        assert len(tokens) == 50
        assert all(len(token) >= 60 for token in tokens)

    def test_hash_is_deterministic_and_hides_the_token(self) -> None:
        token = generate_refresh_token()

        assert hash_refresh_token(token) == hash_refresh_token(token)
        assert token not in hash_refresh_token(token)
        assert len(hash_refresh_token(token)) == 64


class TestRateLimiter:
    def test_blocks_after_the_limit_and_recovers_after_the_window(self) -> None:
        now = 1000.0
        limiter = RateLimiter(limit=2, window_seconds=60, clock=lambda: now)

        limiter.hit("ip")
        limiter.hit("ip")
        with pytest.raises(TooManyRequestsError) as blocked:
            limiter.hit("ip")
        assert blocked.value.headers == {"Retry-After": "60"}

        now += 61
        limiter.hit("ip")

    def test_keys_are_independent(self) -> None:
        limiter = RateLimiter(limit=1, window_seconds=60)

        limiter.hit("a")
        limiter.hit("b")
        with pytest.raises(TooManyRequestsError):
            limiter.hit("a")

    def test_reset_clears_the_counters(self) -> None:
        limiter = RateLimiter(limit=1, window_seconds=60)
        limiter.hit("a")

        limiter.reset()

        limiter.hit("a")


class TestCursor:
    def test_round_trip(self) -> None:
        cursor = Cursor(sort="popular", key=42, id=USER_ID)

        assert decode_cursor(encode_cursor(cursor), expected_sort="popular") == cursor

    def test_rejects_cursor_of_another_sort(self) -> None:
        encoded = encode_cursor(Cursor(sort="popular", key=42, id=USER_ID))

        with pytest.raises(InvalidCursorError):
            decode_cursor(encoded, expected_sort="price_asc")

    @pytest.mark.parametrize("garbage", ["", "abc", "!!!!", "eyJ4IjoxfQ", "bnVsbA"])
    def test_rejects_garbage(self, garbage: str) -> None:
        with pytest.raises(InvalidCursorError):
            decode_cursor(garbage, expected_sort="popular")


class TestSearchText:
    def test_removes_accents_case_and_extra_spaces(self) -> None:
        assert normalize_text("  Salão   de FESTAS São João ") == "salao de festas sao joao"

    def test_joins_the_parts_that_exist(self) -> None:
        assert build_search_text("Salão Glamour", None, "Rio de Janeiro", "RJ") == (
            "salao glamour rio de janeiro rj"
        )
