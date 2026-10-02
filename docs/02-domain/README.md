---
title: Domínio — mapa
type: domain
updated: 2026-10-02
---

# Domínio — mapa

Os assuntos do negócio e como se ligam. Cada um tem o mesmo nome no app
(`lib/features/`) e na API (`backend/app/modules/`).

```
Conta ──┬── favorita ──────────▶ Anúncio ◀── pertence a ── Fornecedor ◀── é de ── Conta
        │                           ▲                          │
        └── monta ── Festa ── item ─┘                          └── analisado por ── Administrador
```

| Assunto | Documento | App | API |
|---|---|---|---|
| Contas e sessão | [accounts](accounts.md) | `features/auth`, `features/client/profile` | `modules/accounts` |
| Catálogo e favoritos | [catalog](catalog.md) | `features/catalog`, `features/client` | `modules/catalog`, `modules/favorites` |
| Festas | [Party Maker](../03-features/party-maker/domain.md) | `features/party_maker` | `modules/parties` |
| Fornecedores e análise | [vendors-and-review](vendors-and-review.md) | `features/vendor`, `features/admin` | `modules/vendors` |

Todas as regras em uma tabela, com onde cada uma é garantida:
[business-rules](business-rules.md).

## Fronteiras

- O **Party Maker não conhece o catálogo**. Quem chama traduz o anúncio para
  `PartyItemDraft` (`listing_actions.dart`). Na API, a festa só conhece o
  catálogo por uma função de consulta (`CatalogLookup`).
- **Anúncio é do fornecedor, não da conta**: apagar a conta apaga o cadastro e,
  com ele, os anúncios.
- **Administração não é um módulo próprio na API**: as rotas `/admin` vivem em
  `modules/vendors`, porque só existe análise de fornecedores e anúncios.
