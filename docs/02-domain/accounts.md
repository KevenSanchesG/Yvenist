---
title: Contas e sessão
type: domain
updated: 2026-10-02
---

# Contas e sessão

App: `lib/features/auth`. API: `backend/app/modules/accounts`. Telas:
[auth-and-account](../03-features/auth-and-account.md). Motivos das escolhas:
[ADR-004](../05-decisions/ADR-004-autenticacao.md).

## Entidades

| Entidade | Campos que importam |
|---|---|
| Conta (`AppUser` / `users`) | `id`, `email`, `fullName`, `phone` (opcional, só dígitos), `birthDate` (opcional), `isAdmin` |
| Sessão (`refresh_tokens`) | uma por aparelho; hash do token, família, identificação do aparelho, validade |

## Regras

| Regra | Garantida em |
|---|---|
| E-mail único, comparado em minúsculas | índice único em `users.email` |
| Senha com pelo menos 8 caracteres | `auth_validators.dart` (app) e `accounts/schemas.py` (API) |
| Senha fora da lista das mais comuns | só na API (`accounts/passwords.py`); o app mostra o erro no campo |
| Criar conta exige aceitar os termos; a versão aceita fica registrada | `users.terms_version`, `accept_terms` no cadastro |
| Login com e-mail ou senha errados responde igual, sem dizer qual | `accounts/service.py` |
| Trocar a senha encerra as outras sessões e invalida os tokens de acesso | `users.token_version` |
| Apagar a conta exige a senha e apaga tudo que é dela | `POST /users/me/delete` |
| Conta desativada (`is_active` falso) não autentica | `api/deps.py` |
| Administrador só nasce pela linha de comando | `python -m app.cli create-admin` |

## Sessão

- Token de acesso (15 min) + token de renovação (30 dias), trocados juntos a
  cada renovação.
- Um token de renovação já trocado que reaparece encerra todas as sessões
  daquela família: é sinal de cópia.
- O app guarda os dois no cofre do sistema e recupera a sessão ao abrir
  (`SessionController.restore`). Sem rede, a sessão guardada não é apagada.
- Sessão expirada no meio do uso: `ApiClient.onSessionExpired` avisa o
  `SessionController`, e favoritos, festas e cadastro de fornecedor trocam para
  "sem conta" (`AppState._onSessionChanged`).

## Modo demonstração

`InMemoryAuthRepository`: o app já abre autenticado na conta
`demo@yvenist.app` (senha `demonstracao`, anunciada na tela de entrada). Apagar
essa conta a recria zerada, com outro id.

## O que não existe

Recuperar senha, confirmar e-mail, autenticação em dois fatores, tela de
dispositivos conectados (a API já lista e encerra sessões). Veja o
[roadmap](../00-project/roadmap.md).
