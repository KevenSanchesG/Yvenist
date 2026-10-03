---
title: A API (FastAPI)
type: architecture
updated: 2026-10-03
---

# A API (FastAPI)

FastAPI + SQLAlchemy 2 **síncrono** + Alembic. PostgreSQL em produção, SQLite
para desenvolver. Motivo: [ADR-003](../05-decisions/ADR-003-api-monolito-modular.md).
Como rodar e configurar: [`backend/README.md`](../../backend/README.md).

## Organização

```
backend/app/
  main.py        monta a aplicação (create_app); CORS; saúde
  cli.py         create-admin, seed-demo, purge-tokens
  api/           dependências HTTP (usuário atual, administrador, limite) e agregação das rotas
  core/          config, banco, segurança, erros, paginação, logs, limite de requisições, documentos
  modules/
    accounts/    cadastro, login, sessões, dados pessoais, senhas comuns
    catalog/     categorias, tipos de evento, busca de anúncios
    favorites/   favoritos
    parties/     festas (regras em domain.py, sem banco nem HTTP)
    vendors/     cadastro de fornecedor, anúncios próprios, fila de análise
backend/migrations/   Alembic
backend/tests/
```

Cada módulo: `router.py` (HTTP) → `service.py` (caso de uso e transação) →
`models.py` (tabelas), com `schemas.py` como contrato de entrada e saída. Rotas
não falam com o banco; serviços não conhecem HTTP.

## Rotas

Todas sob `/api/v1`, menos as de saúde. São 30 operações mais 2 de saúde. A
referência completa é a documentação gerada em `/docs` (desligada em produção).

| Método e rota | Acesso | O que faz |
|---|---|---|
| `POST /auth/register` | público, limitado por IP | cria a conta e a sessão |
| `POST /auth/login` | público, limitado por IP | abre uma sessão |
| `POST /auth/refresh` | público | troca o token de renovação por um par novo |
| `POST /auth/logout` | público | encerra a sessão do token informado |
| `GET` `PATCH /users/me` | conta | dados pessoais |
| `POST /users/me/password` | conta | troca a senha e derruba as outras sessões |
| `POST /users/me/delete` | conta | apaga a conta e tudo que é dela |
| `GET /users/me/sessions`, `DELETE /users/me/sessions/{id}` | conta | sessões abertas |
| `GET /catalog/categories`, `/catalog/event-types` | público | dados de referência |
| `GET /catalog/listings`, `/catalog/listings/{id}` | público | busca e detalhe de anúncios publicados |
| `GET /favorites`, `PUT` `DELETE /favorites/{listing_id}` | conta | favoritos |
| `GET /parties`, `GET` `PUT` `DELETE /parties/{id}` | conta (dono) | festas |
| `GET /vendors/me`, `/vendors/me/listings`, `POST /vendors/onboarding` | conta | cadastro de fornecedor |
| `GET /admin/vendors`, `POST /admin/vendors/{id}/approve` `/reject` | administrador | análise de cadastros |
| `GET /admin/listings`, `POST /admin/listings/{id}/approve` `/reject` | administrador | análise de anúncios |
| `GET /health/live`, `/health/ready` | público | o processo está no ar; o banco responde |

Busca (`GET /catalog/listings`): `q`, `category`, `event_type`,
`min_price_cents`, `max_price_cents`, `sort` (`popular` por padrão), `limit`
(20; máximo 50), `cursor`.

## Contratos que valem para tudo

- **Erro** sempre com a mesma forma, em português:
  `{"error": {"code", "message", "details"?, "request_id"}}`. Erros por campo
  em `details.fields` como `[{"field", "message"}]`; a tradução fica em
  `core/errors.py`. O valor enviado nunca volta na resposta.
- **Dinheiro** inteiro, em centavos. **Datas** em UTC. **Ids** UUID.
- **Paginação** por cursor, não por `OFFSET` (`core/pagination.py`).
- **Busca** ignora acentos e maiúsculas por uma coluna de texto normalizado
  (`listings.search_text`).
- Toda resposta leva `X-Request-ID`, `Cache-Control: no-store`,
  `X-Content-Type-Options: nosniff` e `Referrer-Policy: no-referrer`; em
  produção, também `Strict-Transport-Security` (`core/logging.py`).

## Autenticação

Resumo; o motivo de cada escolha está no [ADR-004](../05-decisions/ADR-004-autenticacao.md).

- Senha com Argon2id, mínimo de 8 caracteres, recusa das mais comuns
  (`accounts/passwords.py`).
- Token de acesso JWT de 15 minutos; token de renovação opaco, do qual o banco
  guarda só o SHA-256.
- Rotação a cada renovação; token já trocado que reaparece encerra a família.
- Trocar a senha incrementa `users.token_version` e invalida os tokens de
  acesso anteriores.

## Concorrência

| Situação | Garantia |
|---|---|
| mesmo e-mail cadastrado duas vezes ao mesmo tempo | índice único → 409 |
| mesmo CPF/CNPJ em dois cadastros | índice único → 409 |
| a mesma conta envia o cadastro de fornecedor duas vezes | índice único → 409 `onboarding_in_progress` |
| mesmo token de renovação usado em paralelo | `SELECT ... FOR UPDATE` → só uma troca |
| dois aparelhos gravando a mesma festa | trava na linha + `version` → o segundo recebe 409 |
| dois salões na mesma festa | índice único parcial |
| dois administradores decidindo o mesmo item | trava na linha → o segundo recebe 409 `already_reviewed` |

`tests/test_concurrency.py` dispara requisições simultâneas de verdade contra o
PostgreSQL para oito delas: e-mail, token de renovação, favorito, festa criada
duas vezes, edição da mesma versão, documento em duas contas, envio duplo do
cadastro e análise dupla. A regra do salão único é testada sem simultaneidade
(`test_parties.py`).

## Limites embutidos

| Limite | Valor | Onde |
|---|---|---|
| festas por conta | 100 | `parties/service.py` |
| itens por festa | 50 | `parties/domain.py` |
| quantidade de um item | 999 | `parties/domain.py` |
| favoritos por conta | 500 | `favorites/service.py` |
| anúncios por fornecedor | 50 | `vendors/service.py` |
| preço de um anúncio ou de um serviço próprio | R$ 1 milhão | `catalog/pricing.py` |
| serviços próprios por anúncio | 20 | `vendors/schemas.py` |
| parceiros por anúncio | 20 | `vendors/schemas.py` |
| fila de análise | 50 por consulta, sem paginação | `vendors/service.py` |
| login / cadastro por IP | 10 / 5 por minuto | `core/config.py` |
