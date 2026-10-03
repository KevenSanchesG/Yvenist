---
title: Domínio — mapa
type: domain
updated: 2026-10-03
---

# Domínio — mapa

Os assuntos do negócio e como se ligam. Cada um tem o mesmo nome no app
(`lib/features/`) e na API (`backend/app/modules/`).

```
Conta ──┬── favorita ──────────▶ Anúncio ◀── pertence a ── Fornecedor ◀── é de ── Conta
        │                           ▲                          │
        └── monta ── Festa ── item ─┘                          └── analisado por ── Administrador
                               │
                               └── pedido de orçamento ──▶ o fornecedor do anúncio, que responde
```

| Assunto | Documento | App | API |
|---|---|---|---|
| Contas e sessão | [accounts](accounts.md) | `features/auth`, `features/client/profile` | `modules/accounts` |
| Catálogo e favoritos | [catalog](catalog.md) | `features/catalog`, `features/client` | `modules/catalog`, `modules/favorites` |
| Festas e orçamentos | [Party Maker](../03-features/party-maker/domain.md) | `features/party_maker` | `modules/parties` (o lado de quem monta), `modules/quotes` (o lado do fornecedor que responde) |
| Fornecedores e análise | [vendors-and-review](vendors-and-review.md) | `features/vendor`, `features/admin` | `modules/vendors` |

Todas as regras em uma tabela, com onde cada uma é garantida:
[business-rules](business-rules.md).

## Fronteiras

- O **Party Maker não conhece o catálogo**. Ele declara o que precisa saber de
  um anúncio (`PartyItemCatalog`, que devolve um `PartyItemDraft`), e quem
  conhece os dois lados traduz (`ListingPartyItemCatalog`, em
  `client/shared/listing_party_item_catalog.dart`). Na API, as regras da festa
  só conhecem o catálogo por duas funções de consulta (`Catalog`, em
  `parties/domain.py`), que o serviço atende lendo só anúncios publicados
  (`_CatalogReader`).
- **O pedido de orçamento não é uma entidade à parte**: é um item de uma festa
  com o orçamento solicitado, visto pelo fornecedor do anúncio
  (`quotes/service.py`). A resposta é gravada no próprio item.
- **Anúncio é do fornecedor, não da conta**: apagar a conta apaga o cadastro e,
  com ele, os anúncios.
- **Administração não é um módulo próprio na API**: as rotas `/admin` vivem em
  `modules/vendors`, porque só existe análise de fornecedores e anúncios.
