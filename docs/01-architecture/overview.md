---
title: Arquitetura — visão geral
type: architecture
updated: 2026-10-02
---

# Arquitetura — visão geral

```
┌──────────────────────────┐        HTTPS / JSON        ┌───────────────────┐       ┌────────────┐
│  App Flutter             │ ─────────────────────────▶ │  API (FastAPI)    │ ────▶ │ PostgreSQL │
│  Android · iOS · web     │ ◀───────────────────────── │  /api/v1          │ ◀──── │            │
└──────────────────────────┘                            └───────────────────┘       └────────────┘
        │
        └── ou, sem API_BASE_URL: dados em memória (modo demonstração)
```

Um **monólito modular** dos dois lados: um app, uma API, um banco. Não há
microsserviços, fila nem cache distribuído ([ADR-003](../05-decisions/ADR-003-api-monolito-modular.md)).

## As peças

| Peça | Onde | Detalhe |
|---|---|---|
| App | `lib/` | [clean-architecture](clean-architecture.md) |
| API | `backend/app/` | [backend](backend.md) |
| Banco | `backend/migrations/` | [data-model](data-model.md) |
| Testes | `test/`, `backend/tests/` | [testing](testing.md) |
| Automação | `.github/workflows/ci.yml` | [CI](../09-guides/ci.md) |
| Memória do projeto | `CLAUDE.md`, `.claude/`, `docs/` | [memory-system](../00-project/memory-system.md) |

## Os dois modos do app

| Modo | Quando | Quem atende os contratos |
|---|---|---|
| Demonstração | build sem `--dart-define=API_BASE_URL` | repositórios `InMemory*` |
| API | build com `API_BASE_URL` válida | repositórios `Api*` + `ApiClient` |

A escolha é feita uma vez, em `lib/app/app_dependencies.dart`. As telas não
sabem em que modo estão ([ADR-001](../05-decisions/ADR-001-camadas-por-funcionalidade.md)).

Um valor **errado** em `API_BASE_URL` não cai no modo demonstração: `main.dart`
mostra `ConfigErrorApp`. Build de release só aceita `https`, exceto para o
próprio aparelho (`localhost`, `127.0.0.1`, `::1`) — `lib/core/config/app_config.dart`.

## O caminho de uma ação

Exemplo: tocar em "Solicitar orçamento".

1. `PartyBuilderPage` chama `PartyMakerController.lockActivePartyForPayment()`.
2. O controller executa o caso de uso `LockPartyForPaymentUseCase`.
3. O agregado `Party` aplica a regra no aparelho (`lockForPayment`).
4. `PartyRepository.save` grava: em memória, ou `PUT /parties/{id}` com o
   estado desejado e a versão conhecida.
5. Na API, `parties/router.py` → `PartyService.save_party` → `domain.reconcile`
   valida de novo e grava.
6. A festa volta como ficou gravada e substitui a cópia do app.
7. Qualquer falha vira `AppFailure` com mensagem em português, mostrada em um
   aviso; a tela nunca recebe uma exceção.

## Onde mexer

| Quero mudar... | Comece por |
|---|---|
| uma regra da festa | `lib/features/party_maker/domain/` **e** `backend/app/modules/parties/domain.py` (as duas têm de concordar) |
| uma tela | `lib/features/<funcionalidade>/presentation/pages/` |
| uma chamada à API | `lib/features/<funcionalidade>/data/api_*_repository.dart` |
| uma rota | `backend/app/modules/<módulo>/router.py` e `service.py` |
| uma tabela | `models.py` do módulo + uma migração nova em `backend/migrations/versions/` |
| cor, fonte, espaçamento | `lib/core/theme/` |
| qual implementação é usada | `lib/app/app_dependencies.dart` |
| configuração da API | `backend/app/core/config.py` (variáveis `YVENIST_*`) |
