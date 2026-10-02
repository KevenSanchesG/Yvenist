"""Comportamentos transversais da API: erros, cabeçalhos, saúde e documentação."""

import logging

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.main import create_app
from app.models import Base
from tests.conftest import AuthenticatedUser, make_settings


def build_app(**settings: object) -> FastAPI:
    application = create_app(make_settings(**settings))
    Base.metadata.create_all(application.state.engine)
    return application


def fields_of(response) -> dict[str, str]:
    """Os erros por campo de uma resposta 422: {campo: mensagem}."""
    assert response.status_code == 422, response.text
    return {
        field["field"]: field["message"] for field in response.json()["error"]["details"]["fields"]
    }


class TestErrorFormat:
    def test_unknown_route_uses_the_standard_error_body(self, client: TestClient) -> None:
        response = client.get("/api/v1/nao-existe")

        assert response.status_code == 404
        error = response.json()["error"]
        assert error["code"] == "not_found"
        assert error["message"] == "Recurso não encontrado."
        assert error["request_id"] == response.headers["x-request-id"]

    def test_wrong_method_uses_the_standard_error_body(self, client: TestClient) -> None:
        response = client.delete("/api/v1/catalog/categories")

        assert response.status_code == 405
        assert response.json()["error"]["code"] == "method_not_allowed"

    def test_validation_error_points_to_the_fields(self, client: TestClient) -> None:
        response = client.post(
            "/api/v1/auth/register",
            json={"email": "x", "password": "curta", "full_name": "Ana", "accept_terms": True},
        )

        assert response.status_code == 422
        error = response.json()["error"]
        assert error["code"] == "validation_error"
        # A mensagem de cada campo vai para a tela do app: em português, e sem
        # devolver o valor enviado (que aqui inclui a senha).
        assert {field["field"]: field["message"] for field in error["details"]["fields"]} == {
            "email": "E-mail inválido.",
            "password": "Use pelo menos 8 caracteres.",
        }
        assert "curta" not in response.text

    def test_missing_and_mistyped_fields_are_explained_in_portuguese(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        missing = client.post("/api/v1/auth/login", json={"email": "ana@example.com"})
        mistyped = client.put(
            "/api/v1/parties/nao-e-um-uuid",
            headers=user.headers,
            json={"title": "Festa", "status": "nao-existe", "items": "nenhum"},
        )

        assert fields_of(missing) == {"password": "Campo obrigatório."}
        assert fields_of(mistyped) == {
            "party_id": "Identificador inválido.",
            "status": "Opção inválida.",
            "items": "Informe uma lista.",
        }

    def test_messages_written_by_our_validators_come_through_unchanged(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.patch(
            "/api/v1/users/me",
            headers=user.headers,
            json={"phone": "123", "full_name": "A"},
        )

        assert fields_of(response) == {
            "phone": "Telefone inválido.",
            "full_name": "Informe o nome completo.",
        }

    def test_limits_carry_their_numbers(self, client: TestClient, user: AuthenticatedUser) -> None:
        response = client.post(
            "/api/v1/auth/register",
            json={
                "email": "ana@example.com",
                "password": "x" * 129,
                "full_name": "Ana",
                "accept_terms": True,
            },
        )

        assert fields_of(response) == {"password": "Use no máximo 128 caracteres."}

    def test_malformed_json_is_a_validation_error(self, client: TestClient) -> None:
        response = client.post(
            "/api/v1/auth/login",
            content="{isso não é json",
            headers={"Content-Type": "application/json"},
        )

        assert response.status_code == 422
        assert response.json()["error"]["code"] == "validation_error"

    def test_unexpected_error_does_not_leak_internals(
        self, app: FastAPI, caplog: pytest.LogCaptureFixture
    ) -> None:
        @app.get("/explode")
        def explode() -> None:
            raise RuntimeError("senha do banco: hunter2")

        with (
            TestClient(app, raise_server_exceptions=False) as client,
            caplog.at_level(logging.ERROR),
        ):
            response = client.get("/explode")

        assert response.status_code == 500
        assert response.json()["error"]["code"] == "internal_error"
        assert "hunter2" not in response.text
        # O detalhe fica só no log do servidor.
        assert "hunter2" in caplog.text


class TestRequestId:
    def test_every_response_has_a_request_id(self, client: TestClient) -> None:
        first = client.get("/health/live").headers["x-request-id"]
        second = client.get("/health/live").headers["x-request-id"]

        assert first and second and first != second

    def test_reuses_a_well_formed_incoming_id(self, client: TestClient) -> None:
        response = client.get("/health/live", headers={"X-Request-ID": "abc-123"})

        assert response.headers["x-request-id"] == "abc-123"

    @pytest.mark.parametrize("value", ["tem espaco", "x" * 65, "quebra\tde-log"])
    def test_replaces_a_suspicious_incoming_id(self, client: TestClient, value: str) -> None:
        response = client.get("/health/live", headers={"X-Request-ID": value})

        assert response.headers["x-request-id"] != value


class TestSecurityHeaders:
    def test_responses_carry_the_hardening_headers(
        self, client: TestClient, user: AuthenticatedUser
    ) -> None:
        response = client.get("/api/v1/users/me", headers=user.headers)

        assert response.headers["x-content-type-options"] == "nosniff"
        assert response.headers["referrer-policy"] == "no-referrer"
        assert response.headers["cache-control"] == "no-store"

    def test_errors_carry_them_too(self, client: TestClient) -> None:
        response = client.get("/api/v1/users/me")

        assert response.status_code == 401
        assert response.headers["x-content-type-options"] == "nosniff"
        assert response.headers["cache-control"] == "no-store"


class TestHealth:
    def test_liveness(self, client: TestClient) -> None:
        response = client.get("/health/live")

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    def test_readiness_checks_the_database(self, client: TestClient) -> None:
        assert client.get("/health/ready").json() == {"status": "ok"}

    def test_readiness_fails_when_the_database_is_down(
        self, app: FastAPI, caplog: pytest.LogCaptureFixture
    ) -> None:
        class BrokenEngine:
            def connect(self) -> None:
                from sqlalchemy.exc import OperationalError

                raise OperationalError("SELECT 1", {}, Exception("conexão recusada"))

            def dispose(self) -> None:
                pass

        with TestClient(app) as client:
            healthy_engine = app.state.engine
            app.state.engine = BrokenEngine()
            try:
                response = client.get("/health/ready")
            finally:
                app.state.engine = healthy_engine

        assert response.status_code == 503
        assert response.json() == {"status": "unavailable"}


class TestDocs:
    def test_docs_are_available_outside_production(self, client: TestClient) -> None:
        assert client.get("/docs").status_code == 200
        assert client.get("/openapi.json").status_code == 200

    def test_docs_are_hidden_in_production(self) -> None:
        application = build_app(env="production", password_hash_profile="recommended")

        with TestClient(application) as client:
            assert client.get("/docs").status_code == 404
            assert client.get("/openapi.json").status_code == 404
            assert client.get("/health/live").status_code == 200


class TestCors:
    def test_is_off_by_default(self, client: TestClient) -> None:
        response = client.get("/health/live", headers={"Origin": "https://qualquer.site"})

        assert "access-control-allow-origin" not in response.headers

    def test_allows_only_the_configured_origins(self) -> None:
        application = build_app(cors_origins=["https://app.yvenist.com"])

        with TestClient(application) as client:
            allowed = client.get("/health/live", headers={"Origin": "https://app.yvenist.com"})
            denied = client.get("/health/live", headers={"Origin": "https://malicioso.site"})

        assert allowed.headers["access-control-allow-origin"] == "https://app.yvenist.com"
        assert "access-control-allow-origin" not in denied.headers
        assert "access-control-allow-credentials" not in allowed.headers

    def test_preflight_allows_what_the_web_app_sends(self) -> None:
        application = build_app(cors_origins=["https://app.yvenist.com"])

        with TestClient(application) as client:
            # O navegador pergunta antes de mandar JSON com o token de acesso.
            preflight = client.options(
                "/api/v1/parties/qualquer",
                headers={
                    "Origin": "https://app.yvenist.com",
                    "Access-Control-Request-Method": "PUT",
                    "Access-Control-Request-Headers": "authorization,content-type",
                },
            )

        assert preflight.status_code == 200
        assert "PUT" in preflight.headers["access-control-allow-methods"]
        allowed_headers = preflight.headers["access-control-allow-headers"].lower()
        assert "authorization" in allowed_headers
        assert "content-type" in allowed_headers

    def test_exposes_the_headers_the_web_app_needs_to_read(self) -> None:
        # Sem isto o navegador esconde do app o tempo de espera de um 429 e o
        # id da requisição, que fora do navegador sempre estiveram visíveis.
        application = build_app(cors_origins=["https://app.yvenist.com"])

        with TestClient(application) as client:
            response = client.get("/health/live", headers={"Origin": "https://app.yvenist.com"})

        exposed = response.headers["access-control-expose-headers"].lower()
        assert "retry-after" in exposed
        assert "x-request-id" in exposed
